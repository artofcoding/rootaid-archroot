#!/usr/bin/env bash
# Copyright (C) 2020 art of coding UG, Hamburg

set -o nounset
set -o errexit

execdir="$(pushd $(dirname $0) >/dev/null ; pwd ; popd >/dev/null)"

echo "Setting up MinIO mc"
export $(cat "${execdir}"/../variables.env)

echo "Copying policies to MinIO mc"
container="storage_mc_1"
docker cp "${execdir}"/policy/admin.json ${container}:/var/local
docker cp "${execdir}"/policy/userManager.json ${container}:/var/local

echo "Configuring MinIO mc"
docker-compose exec mc \
    mc config host add minio http://minio:9000 ${MINIO_ACCESS_KEY} ${MINIO_SECRET_KEY} --api S3v4
docker-compose exec mc \
    mc admin policy add minio userManager /var/local/userManager.json
echo "done"

exit 0