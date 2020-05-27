#!/usr/bin/env bash
# Copyright (C) 2020 art of coding UG, Hamburg

set -o nounset
set -o errexit

execdir="$(pushd $(dirname $0) >/dev/null ; pwd ; popd >/dev/null)"
instancedir="${execdir}/instance"

export $(cat "${execdir}"/../variables.env)

echo "Setting up nginx ${HOSTNAME}"

echo "Copying configuration to nginx"
mkdir -p "${instancedir}"
cat "${execdir}"/minio.tmpl.conf \
    | sed -e "s#HOSTNAME#${MINIO_HOSTNAME}#g" \
    >"${instancedir}"/minio.conf.disabled
cat "${execdir}"/hoerbuchdienst.tmpl.conf \
    | sed -e "s#HOSTNAME#${HBD_HOSTNAME}#g" \
    >"${instancedir}"/hoerbuchdienst.conf.disabled

echo "Starting nginx"
docker-compose up -d --no-deps rproxy
sleep 5

container="storage_rproxy_1"
docker cp "${instancedir}"/minio.conf.disabled ${container}:/etc/nginx/conf.d/
docker cp "${instancedir}"/hoerbuchdienst.conf.disabled ${container}:/etc/nginx/conf.d/

echo "Creating TLS server certificates"
hostname="$(hostname -f)"
certonly_args="--agree-tos -m support@rootaid.de
    --webroot --webroot-path=/var/lib/letsencrypt
    --uir
    --hsts
    --staple-ocsp --must-staple
    -n"
docker-compose exec rproxy \
    mkdir /var/lib/letsencrypt
docker-compose exec rproxy \
    certbot certonly ${certonly_args} -d "vault.${hostname}"
docker-compose exec rproxy \
    certbot certonly ${certonly_args} -d "kes.${hostname}"
docker-compose exec rproxy \
    certbot certonly ${certonly_args} -d "s3.${hostname}"
docker-compose exec rproxy \
    certbot certonly ${certonly_args} -d "rabbitmq.${hostname}"
docker-compose exec rproxy \
    certbot certonly ${certonly_args} -d "hoerbuchdienst.${hostname}"

echo "Activating nginx configuration"
docker-compose exec rproxy \
    mv /etc/nginx/conf.d/minio.conf.disabled /etc/nginx/conf.d/minio.conf

docker-compose down

exit 0
