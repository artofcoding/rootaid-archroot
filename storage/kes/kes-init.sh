#!/usr/bin/env bash
# Copyright (C) 2020 art of coding UG, Hamburg

set -o nounset
set -o errexit

execdir="$(pushd $(dirname $0) >/dev/null ; pwd ; popd >/dev/null)"
instancedir="${execdir}/instance"

echo "Setting up MinIO KES"
container="storage_kes_1"

echo "Creating MinIO KES service"
docker-compose up --no-start kes

mkdir -p ${instancedir}/keys
if [[ "${USE_LETSENCRYPT}" != "yes" ]]
then
    if [[ ! -d ${instancedir}/keys ]]
    then
        echo "Creating MinIO KES self-signed TLS certificates"
        openssl ecparam -genkey -name prime256v1 \
            | openssl ec -out ${instancedir}/keys/kes-server.key
        openssl req -new -x509 \
            -days 30 \
            -key ${instancedir}/keys/kes-server.key \
            -out ${instancedir}/keys/kes-server.cert \
            -subj "/C=/ST=/L=/O=/CN=kes" \
            -addext "subjectAltName = IP:127.0.0.1,DNS:${KES_HOSTNAME}"
    fi
    docker cp "${instancedir}"/keys/kes-server.key ${container}:/var/local
    docker cp "${instancedir}"/keys/kes-server.cert ${container}:/var/local
fi

echo "Configuring Vault for MinIO KES"
mkdir -p ${instancedir}/config
vault_cli="docker-compose exec -e VAULT_ADDR=https://127.0.0.1:8200 -e VAULT_SKIP_VERIFY=1 vault vault"
kes_role="auth/approle/role/kes-role"
${vault_cli} read ${kes_role}/role-id -format=json | tee ${instancedir}/config/role-id.json
approle_id="$(cat ${instancedir}/config/role-id.json | jq -r .data.role_id)"
export approle_id=${approle_id}
${vault_cli} write -f ${kes_role}/secret-id -format=json | tee ${instancedir}/config/secret-id.json
approle_secret_id="$(cat ${instancedir}/config/secret-id.json | jq -r .data.secret_id)"
export approle_secret_id=${approle_secret_id}

echo "Creating MinIO KES keys"
kes_init_cli="docker run \
        --rm \
        --mount type=bind,source=${instancedir}/keys,destination=/instance/keys \
        minio/kes:${KES_RELEASE}"

if [[ ! -f ${instancedir}/keys/root.key || ! -f ${instancedir}/keys/root.cert ]]
then
    rm -f ${instancedir}/keys/root.*
    ${kes_init_cli} tool identity new --key=/instance/keys/root.key --cert=/instance/keys/root.cert root
fi
root_identity="$(${kes_init_cli} tool identity of /instance/keys/root.cert)"
echo "Identity of root.cert: ${root_identity}"
docker cp "${instancedir}"/keys/root.key ${container}:/var/local
docker cp "${instancedir}"/keys/root.cert ${container}:/var/local
if [[ ! -f ${instancedir}/keys/minio.key || ! -f ${instancedir}/keys/minio.cert ]]
then
    rm -f ${instancedir}/keys/minio.*
    ${kes_init_cli} tool identity new --key=/instance/keys/minio.key --cert=/instance/keys/minio.cert minio
fi
minio_identity="$(${kes_init_cli} tool identity of /instance/keys/minio.cert)"
echo "Identity of minio: ${minio_identity}"
docker cp "${instancedir}"/keys/minio.key ${container}:/var/local
docker cp "${instancedir}"/keys/minio.cert ${container}:/var/local

# server-config
mkdir -p "${execdir}"/instance/config
sed -i'' \
    -e "s#root_identity=.*#root_identity=${root_identity}#" \
    "${execdir}"/../variables.env
cat "${execdir}"/server-config.tmpl.yml \
    | sed \
        -e "s#KES_HOSTNAME#${KES_HOSTNAME}#" \
        -e "s#VAULT_HOSTNAME#${VAULT_HOSTNAME}#" \
        -e "s#ROOT_IDENTITY#${root_identity}#" \
        -e "s#APP_IDENTITY#${minio_identity}#" \
        -e "s#APPROLE_ID#${approle_id}#" \
        -e "s#APPROLE_SECRET_ID#${approle_secret_id}#" \
    >"${execdir}"/instance/config/server-config.yml

echo "Copying configuration to MinIO KES"
docker cp "${instancedir}"/config/server-config.yml ${container}:/var/local

exit 0
