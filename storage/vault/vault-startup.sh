#!/usr/bin/env bash

set -o nounset
set -o errexit

VC="/vault/config"
VCJSON="${VC}/vault-config.json"

echo "Setting filesystem permissions"
chown -R vault:vault /vault/config || echo "Could not chown /vault/config (may not have appropriate permissions)"
chown -R vault:vault /vault/logs || echo "Could not chown /vault/logs (may not have appropriate permissions)"
chown -R vault:vault /vault/file || echo "Could not chown /vault/file (may not have appropriate permissions)"

echo "Starting Vault server"
vault server -config=${VCJSON} &
sleep 2

if [ ! -f ${VC}/vault-operator-init.txt ]
then
    echo "Initializing keys"
    vault operator init -key-shares=6 -key-threshold=3 \
        | tee ${VC}/vault-operator-init.txt
fi

echo "Unsealing Vault"
unseal_keys="$(cat ${VC}/vault-operator-init.txt \
    | grep --color=never "Unseal Key" \
    | sed -e 's#Unseal Key \(.*\): \(.*\)#Unseal_Key_\1=\2#')"
export ${unseal_keys}
vault operator unseal ${Unseal_Key_1}
vault operator unseal ${Unseal_Key_2}
vault operator unseal ${Unseal_Key_3}
for i in $(seq 1 6)
do
    unset Unseal_Key_${i}
done

vault status -format=json

echo "Logging in as root"
ROOT_TOKEN=$(grep "Initial Root Token" ${VC}/vault-operator-init.txt \
    | awk -F':' '{ print substr($2, 2) }')
vault login ${ROOT_TOKEN}

# AppRole
if [ $(vault auth list | grep -c "approle/") -eq 0 ]
then
    echo "Enabling auth by approle"
    vault auth enable approle
fi

# Policies
echo "Writing policies"
vault policy write key-policy /vault/config/kes-policy.hcl

# Minio KES
echo "Enabling Minio KES policy"
kes_role="auth/approle/role/kes-role"
vault write ${kes_role} token_num_uses=0 secret_id_num_uses=0 period=5m
vault write ${kes_role} policies=key-policy

# K/V
vault secrets list
if [ $(vault secrets list | grep -c "kv/") -eq 0 ]
then
    echo "Enabling Vault KV at kv/"
    vault secrets enable -version=1 kv
fi
if [ $(vault secrets list | grep -c "secret/") -eq 0 ]
then
    echo "Enabling Vault KV at secrets/"
    vault secrets enable -version=1 -path=secret kv
fi

tail -f /dev/null

exit 0
