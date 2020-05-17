#!/usr/bin/env bash
# Copyright (C) 2020 art of coding UG, Hamburg

set -o nounset
set -o errexit

execdir="$(pushd $(dirname $0) >/dev/null ; pwd ; popd >/dev/null)"

echo "Starting MinIO KES service"
export $(cat "${execdir}"/../variables.env)
docker-compose up -d kes
sleep 10

# Test
echo "Testing MinIO KES key store"
"${execdir}"/kes-key-test.sh

# MiniIO Key
echo "Creating MinIO master key"
kes_cli="docker-compose exec \
    -e KES_CLIENT_TLS_KEY_FILE=/var/local/minio.key \
    -e KES_CLIENT_TLS_CERT_FILE=/var/local/minio.cert \
    kes kes"
${kes_cli} key create minio-key-1 -k
