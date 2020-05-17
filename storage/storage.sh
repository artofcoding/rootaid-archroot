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
        pushd "${execdir}" >/dev/null
        export $(cat "${execdir}"/variables.env)
        docker-compose down
        rm -rf kes/instance
        rm -rf vault/instance
        rm -rf nginx/instance
        docker system prune -f
        docker volume prune -f
        docker image rm storage_rproxy:latest
        docker image prune -f
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
        export $(cat "${execdir}"/variables.env)
        docker-compose config
        "${execdir}"/vault/vault-init.sh
        "${execdir}"/kes/kes-init.sh
        echo "Copying Vault TLS server certificate to Minio KES"
        container="storage_kes_1"
        docker cp "${execdir}"/vault/instance/keys/vault-server.cert ${container}:/var/local
        echo "done"
        "${execdir}"/kes/kes-firstrun.sh
        "${execdir}"/minio/minio-firstrun.sh
        echo "Copying KES keys to MinIO"
        docker-compose up --no-start --no-deps minio
        container="storage_minio_1"
        container_local="${container}:/var/local"
        docker cp "${execdir}"/kes/instance/keys/minio.key ${container_local}
        docker cp "${execdir}"/kes/instance/keys/minio.cert ${container_local}
        docker cp "${execdir}"/kes/instance/keys/kes-server.cert ${container_local}
        echo "done"
        "${execdir}"/nginx/nginx-firstrun.sh
        docker-compose up -d
        echo "Waiting for services to start..."
        sleep 5
        echo "done"
        docker-compose exec mc \
            mc config host add minio "http://minio:9000" "${MINIO_ACCESS_KEY}" "${MINIO_SECRET_KEY}"
        popd >/dev/null
    ;;
    addpolicy)
        policy_name=$1 ; shift
        bucket_name=$1 ; shift
        pushd "${execdir}" >/dev/null
        cat "${execdir}"/minio/policy/"${policy_name}".json \
            | sed -e "s#BUCKET_NAME#${bucket_name}#g" \
            | sed -e "s#PATH#*#g" \
            >"${execdir}"/minio/policy/"${policy_name}".json.$$
        docker-compose exec mc \
            mc admin policy add minio "${policy_name}" /minio/policy/"${policy_name}".json.$$
        rm "${execdir}"/minio/policy/"${policy_name}".json.$$
        popd >/dev/null
    ;;
    adduser)
        username=$1 ; shift
        password=$1 ; shift
        policy_name=$1 ; shift
        pushd "${execdir}" >/dev/null
        docker-compose exec mc \
            mc admin user add minio "${username}" "${password}"
        popd >/dev/null
    ;;
    userpolicy)
        username=$1 ; shift
        policy_name=$1 ; shift
        pushd "${execdir}" >/dev/null
        docker-compose exec mc \
            mc admin policy set minio "${policy_name}" user="${username}"
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
