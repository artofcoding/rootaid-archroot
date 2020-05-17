#!/usr/bin/env bash
# Copyright (C) 2020 art of coding UG, Hamburg

set -o nounset
set -o errexit

prefix="minio-"

kes_cli="docker-compose exec \
    -e KES_CLIENT_TLS_KEY_FILE=/var/local/minio.key \
    -e KES_CLIENT_TLS_CERT_FILE=/var/local/minio.cert \
    kes kes"

k="${prefix}test-1"

echo "KES test: create ${k}"
${kes_cli} key create ${k} -k
echo "KES test: derive ${k}"
${kes_cli} key derive ${k} -k >derived-key-test.txt
#plaintext="$(jq -r .plaintext derived-key-test.txt)"
plaintext="$(cat derived-key-test.txt | grep plaintext | awk -F':' '{ print substr($2, 2) }')"
#ciphertext="$(jq -r .ciphertext derived-key-test.txt)"
ciphertext="$(cat derived-key-test.txt | grep ciphertext | awk -F':' '{ print substr($2, 2) }')"
rm derived-key-test.txt
#decrypted_ciphertext="$(${kes_cli} key decrypt ${k} -k ${ciphertext} | jq -r .plaintext)"
decrypted_ciphertext="$(${kes_cli} key decrypt ${k} -k ${ciphertext} | grep plaintext | awk -F':' '{ print substr($2, 2) }')"
echo "KES test: plaintext=${plaintext}"
echo "KES test: decrypted_ciphertext=${decrypted_ciphertext}"
#echo "KES test: delete ${k}"
#${kes_cli} key delete ${k} -k

exit 0
