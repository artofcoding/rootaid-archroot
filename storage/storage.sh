#!/usr/bin/env bash
# Copyright (C) 2020 art of coding UG, Hamburg

set -o nounset
set -o errexit

execdir="$(pushd $(dirname $0) >/dev/null ; pwd ; popd >/dev/null)"

usage() {
    echo "usage: $0 < destroy | init | policy | adduser | start | stop >"
    exit 1
}

[[ $# -lt 1 ]] && usage

#[[ $(pacman -Q jq | grep -c jq) != 0 ]] && pacman -S --noconfirm jq

mode=$1 ; shift
case "${mode}" in
    destroy)
        [[ $# -eq 1 ]] && all=$1
        pushd "${execdir}" >/dev/null
        export $(cat "${execdir}"/variables.env)
        docker-compose down
        set +o errexit
        rm -rf kes/instance
        rm -rf vault/instance
        [[ "${all}" == "all" ]] && rm -rf nginx/instance
        docker system prune -f
        docker volume rm storage_kesinstance
        docker volume rm storage_mcrootconfig
        docker volume rm storage_miniodata
        docker volume rm storage_minioinstance
        docker volume rm storage_miniopolicy
        docker volume rm storage_rabbitmqdata
        [[ "${all}" == "all" ]] && docker volume rm storage_rproxycerts
        docker volume rm storage_rproxyconf
        docker volume rm storage_vaultconfig
        docker volume rm storage_vaultfile
        docker volume rm storage_vaultlogs
        [[ "${all}" == "all" ]] && docker image rm storage-rproxy:latest
        [[ "${all}" == "all" ]] && docker image rm storage-rabbitmq:latest
        docker image prune -f
        set -o errexit
        popd >/dev/null
    ;;
    docker-ipv6)
        sysctl net.ipv6.conf.default.forwarding=1
        sysctl net.ipv6.conf.all.forwarding=1
        cat >/etc/docker/daemon.json <<EOF
{
  "ipv6": true,
  "fixed-cidr-v6": "2a03:4000:6:21ed::/64"
}
EOF
    ;;
    init)
        pushd "${execdir}" >/dev/null
        VAULT_HOSTNAME="vault.$(hostname -f)"
        sed -i'' -e "s#VAULT_HOSTNAME=.*#VAULT_HOSTNAME=${VAULT_HOSTNAME}#g" variables.env
        sed -i'' -e "s#/VAULT_HOSTNAME#/${VAULT_HOSTNAME}#g" variables.env
        KES_HOSTNAME="kes.$(hostname -f)"
        sed -i'' -e "s#KES_HOSTNAME=.*#KES_HOSTNAME=${KES_HOSTNAME}#g" variables.env
        sed -i'' -e "s#/KES_HOSTNAME#/${KES_HOSTNAME}#g" variables.env
        MINIO_HOSTNAME="s3.$(hostname -f)"
        MINIO_DOMAIN="s3.$(hostname -f)"
        sed -i'' -e "s#MINIO_HOSTNAME=.*#MINIO_HOSTNAME=${MINIO_HOSTNAME}#g" variables.env
        sed -i'' -e "s#MINIO_DOMAIN=.*#MINIO_DOMAIN=${MINIO_DOMAIN}#g" variables.env
        RABBITMQ_HOSTNAME="rabbitmq.$(hostname -f)"
        sed -i'' -e "s#RABBITMQ_HOSTNAME=.*#RABBITMQ_HOSTNAME=${RABBITMQ_HOSTNAME}#g" variables.env
        sed -i'' -e "s#/RABBITMQ_HOSTNAME#/${RABBITMQ_HOSTNAME}#g" variables.env
        sed -i'' -e "s#RABBITMQ_NODENAME=.*#RABBITMQ_NODENAME=rabbitmq@${RABBITMQ_HOSTNAME}#g" variables.env
        HBD_HOSTNAME="hoerbuchdienst.$(hostname -f)"
        sed -i'' -e "s#HBD_HOSTNAME=.*#HBD_HOSTNAME=${HBD_HOSTNAME}#g" variables.env
        export $(cat "${execdir}"/variables.env)
        docker-compose config
        # nginx
        echo "Building nginx image"
        pushd "${execdir}" >/dev/null
        docker-compose build --build-arg NGINX_RELEASE=${NGINX_RELEASE} rproxy
        popd >/dev/null
        # nginx, no certificates exist
        if [[ $(docker volume ls | grep -c storage_rproxycerts) == 0 ]]
        then
            "${execdir}"/nginx/nginx-firstrun.sh
        fi
        # Vault
        "${execdir}"/vault/vault-init.sh
        # MinIO KES
        "${execdir}"/kes/kes-init.sh
        if [[ -d "${execdir}"/vault/instance/keys ]]
        then
            echo "Copying Vault TLS server certificate to MinIO KES"
            container="storage_kes_1"
            docker cp "${execdir}"/vault/instance/keys/vault-server.cert ${container}:/var/local
            echo "done"
        fi
        "${execdir}"/kes/kes-firstrun.sh
        # MinIO
        "${execdir}"/minio/minio-firstrun.sh
        echo "Copying KES keys to MinIO"
        docker-compose up --no-start minio
        container="storage_minio_1"
        container_local="${container}:/var/local"
        docker cp "${execdir}"/kes/instance/keys/minio.key ${container_local}
        docker cp "${execdir}"/kes/instance/keys/minio.cert ${container_local}
        if [[ -f "${execdir}"/kes/instance/keys/kes-server.cert ]]
        then
            docker cp "${execdir}"/kes/instance/keys/kes-server.cert ${container_local}
        fi
        echo "done"
        # RabbitMQ - TLS certificate
        docker-compose build --build-arg RABBITMQ_RELEASE=${RABBITMQ_RELEASE} rabbitmq
        docker-compose up -d --no-deps rproxy
        docker-compose exec rproxy ls -l /etc/letsencrypt/archive/${RABBITMQ_HOSTNAME}/
        docker-compose exec rproxy chmod 644 /etc/letsencrypt/archive/${RABBITMQ_HOSTNAME}/privkey1.pem
        docker-compose exec rproxy chmod 644 /etc/letsencrypt/archive/${RABBITMQ_HOSTNAME}/cert1.pem
        # RabbitMQ
        echo "Starting RabbitMQ"
        docker-compose up -d rabbitmq
        echo "Initializing RabbitMQ"
        docker-compose exec rabbitmq /usr/local/bin/rabbitmq-firstrun.sh
        #
        echo "Waiting for services to start..."
        docker-compose up -d
        sleep 10
        echo "done"
        "${execdir}"/minio/mc-firstrun.sh
        popd >/dev/null
    ;;
    addpolicy)
        policy_name=$1 ; shift
        pushd "${execdir}" >/dev/null
        docker-compose exec mc \
            mc admin policy add minio "${policy_name}" /var/local/"${policy_name}".json
        popd >/dev/null
    ;;
    adduser)
        username=$1 ; shift
        password=$1 ; shift
        policy_name=$1 ; shift
        pushd "${execdir}" >/dev/null
        docker-compose exec mc \
            mc admin user add minio-admin "${username}" "${password}"
        popd >/dev/null
    ;;
    userpolicy)
        username=$1 ; shift
        policy_name=$1 ; shift
        pushd "${execdir}" >/dev/null
        docker-compose exec mc \
            mc admin policy set minio-admin "${policy_name}" user="${username}"
        popd >/dev/null
    ;;
    start)
        pushd "${execdir}" >/dev/null
        export $(cat "${execdir}"/variables.env)
        docker-compose up -d
        popd >/dev/null
    ;;
    stop)
        pushd "${execdir}" >/dev/null
        export $(cat "${execdir}"/variables.env)
        docker-compose down
        popd >/dev/null
    ;;
    *)
        usage
    ;;
esac

exit 0
