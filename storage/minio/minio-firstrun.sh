#!/usr/bin/env bash
# Copyright (C) 2020 art of coding UG, Hamburg

set -o nounset
set -o errexit

execdir="$(pushd $(dirname $0) >/dev/null ; pwd ; popd >/dev/null)"
export $(cat "${execdir}"/../variables.env)

echo "Setting up MinIO"

echo "Creating MinIO service"
docker-compose up --no-start minio
echo "done"

echo "Starting MinIO service to exchange keys"
MINIO_HOSTNAME="${MINIO_HOSTNAME:-storage.$(hostname -f)}"
sed -i'' \
    -e "s#MINIO_HOSTNAME=.*#MINIO_HOSTNAME=${MINIO_HOSTNAME}#" \
    "${execdir}"/../variables.env
MINIO_DOMAIN="${MINIO_DOMAIN:-$(hostname -f)}"
sed -i'' \
    -e "s#MINIO_DOMAIN=.*#MINIO_DOMAIN=${MINIO_DOMAIN}#" \
    "${execdir}"/../variables.env
MINIO_ACCESS_KEY="$(pwgen -Bcn 20 1)"
echo "MINIO_ACCESS_KEY=${MINIO_ACCESS_KEY}"
sed -i'' \
    -e "s#MINIO_ACCESS_KEY=.*#MINIO_ACCESS_KEY=${MINIO_ACCESS_KEY}#" \
    "${execdir}"/../variables.env
MINIO_SECRET_KEY="$(pwgen -Bcn 40 1)"
echo "MINIO_SECRET_KEY=${MINIO_SECRET_KEY}"
sed -i'' \
    -e "s#MINIO_SECRET_KEY=.*#MINIO_SECRET_KEY=${MINIO_SECRET_KEY}#" \
    "${execdir}"/../variables.env
docker-compose up -d minio
sleep 10
docker-compose down
sed -i'' \
    -e "/MINIO_ACCESS_KEY_OLD=\(.*\)/d" \
    "${execdir}"/../variables.env
sed -i'' \
    -e "/MINIO_SECRET_KEY_OLD=\(.*\)/d" \
    "${execdir}"/../variables.env
echo "done"

exit 0
