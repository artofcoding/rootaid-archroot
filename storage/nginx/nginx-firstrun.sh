#!/usr/bin/env bash
# Copyright (C) 2020 art of coding UG, Hamburg

MINIO_HOSTNAME="${MINIO_HOSTNAME:-storage.$(hostname -f)}"

set -o nounset
set -o errexit

execdir="$(pushd $(dirname $0) >/dev/null ; pwd ; popd >/dev/null)"
instancedir="${execdir}/instance"

echo "Setting up nginx"

echo "Configuring nginx image"
mkdir -p "${instancedir}"
cat "${execdir}"/storage.tmpl.conf \
    | sed -e "s#HOSTNAME#${MINIO_HOSTNAME}#g" \
    >"${instancedir}"/storage.conf.disabled

echo "Building nginx image"
pushd "${execdir}" >/dev/null
docker build .
popd >/dev/null

echo "Configuring nginx"
docker-compose up -d --no-deps rproxy
sleep 5
docker-compose exec rproxy \
    mkdir /var/lib/letsencrypt
docker-compose exec rproxy \
    certbot certonly \
        --agree-tos -m support@rootaid.de \
        --webroot --webroot-path=/var/lib/letsencrypt \
        --uir \
        --hsts \
        --staple-ocsp --must-staple \
        -n \
        -d "${MINIO_HOSTNAME}"
docker-compose exec rproxy \
    mv /etc/nginx/conf.d/storage.conf.disabled /etc/nginx/conf.d/storage.conf

docker-compose down

exit 0
