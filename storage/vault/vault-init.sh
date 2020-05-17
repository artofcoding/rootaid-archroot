#!/usr/bin/env bash
# Copyright (C) 2020 art of coding UG, Hamburg

set -o nounset
set -o errexit

execdir="$(pushd $(dirname $0) >/dev/null ; pwd ; popd >/dev/null)"
instancedir="${execdir}/instance"

echo "Setting up Vault in $(pwd)"

echo "Creating Vault service"
docker-compose up --no-start --no-deps vault

if [[ ! -d ${instancedir}/keys ]]
then
    echo "Creating self-signed TLS certificates"
    mkdir -p ${instancedir}/keys
    openssl ecparam -genkey -name prime256v1 \
        | openssl ec -out ${instancedir}/keys/vault-server.key
    openssl req -new -x509 \
        -days 30 \
        -key ${instancedir}/keys/vault-server.key \
        -out ${instancedir}/keys/vault-server.cert \
        -subj "/C=/ST=/L=/O=/CN=vault" \
        -addext "subjectAltName = IP:127.0.0.1,DNS:vault"
fi

container="storage_vault_1"
container_configdir="${container}:/vault/config"
# Vault keys and configuration
docker cp ${instancedir}/keys/vault-server.key ${container_configdir}
docker cp ${instancedir}/keys/vault-server.cert ${container_configdir}
docker cp ${execdir}/vault-config.json ${container_configdir}
# Policies
docker cp ${execdir}/kes-policy.hcl ${container_configdir}
# Vault startup
docker cp ${execdir}/vault-startup.sh ${container}:/vault/config

echo "Starting Vault service"
docker-compose up -d vault
sleep 5

# Test
#vault_cli="docker-compose --no-ansi exec -e VAULT_ADDR=https://127.0.0.1:8200 -e VAULT_SKIP_VERIFY=1 vault vault"
#${vault_cli} kv put secret/my-app/password password=123
#${vault_cli} kv get secret/my-app/password
#${vault_cli} kv get --format=json secret/my-app/password
#${vault_cli} kv get -field=password secret/my-app/password
#${vault_cli} kv list secret/
#${vault_cli} kv delete secret/my-app/password

exit 0
