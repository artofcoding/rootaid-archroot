#!/usr/bin/env bash
# Copyright (C) 2020 art of coding UG, Hamburg

set -o nounset
set -o errexit

execdir="$(pushd $(dirname $0) >/dev/null ; pwd ; popd >/dev/null)"

echo "Setting up MinIO"

echo "Creating MinIO service"
docker-compose up --no-start minio
echo "done"

echo "Copying policies to MinIO"
container="storage_minio_1"
docker cp "${execdir}"/policy/admin.json ${container}:/var/local
docker cp "${execdir}"/policy/userManager.json ${container}:/var/local

echo "Configuring MinIO service to exchange keys"
#MASTER_KEY_HEX=$(head -c 32 /dev/urandom | xxd -c 32 -ps)
#export MINIO_KMS_MASTER_KEY=minio-demo-key:${MASTER_KEY_HEX}
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

echo "Starting MinIO service"
export $(cat "${execdir}"/../variables.env)
docker-compose up -d minio
sleep 10

echo "Stopping MinIO service"
docker-compose down

echo "Removing old MinIO keys"
sed -i'' \
    -e "/MINIO_ACCESS_KEY_OLD=\(.*\)/d" \
    "${execdir}"/../variables.env
sed -i'' \
    -e "/MINIO_SECRET_KEY_OLD=\(.*\)/d" \
    "${execdir}"/../variables.env
echo "done"

echo "Enabling MinIO KMS auto encryption"
sed -i'' \
    -e "s#MINIO_KMS_AUTO_ENCRYPTION=.*#MINIO_KMS_AUTO_ENCRYPTION=on#" \
    "${execdir}"/../variables.env
echo "done"

exit 0
