#!/usr/bin/env bash
# Copyright (C) 2020 art of coding UG, Hamburg

if [[ $(id -u) != 0 ]]
then
    echo "Please execute as root"
    exit 1
fi

if [[ $# -lt 1 ]]
then
    echo "usage: $0 -d <[host.]example.org> [-d <host.example.org> ...]"
    exit 1
fi

set -o nounset
set -o errexit

EMAIL="${EMAIL:-"--register-unsafely-without-email --no-eff-email"}"
certbot certonly \
    ${EMAIL} \
    --agree-tos \
    --webroot --webroot-path=/var/lib/letsencrypt \
    --uir \
    --hsts \
    --staple-ocsp --must-staple \
    -n \
    "$@"

chmod 755 /etc/letsencrypt/archive
chmod 755 /etc/letsencrypt/live
find /etc/letsencrypt/archive -type f -name privkey*.pem -print0 \
    | xargs -r -0 chmod 644

gixy
nginx -s reload
#openssl s_client -connect ${DOMAIN}:443 -servername ${DOMAIN} -status
#echo QUIT | openssl s_client -connect ${DOMAIN}:443 -status 2> /dev/null | grep -A 17 'OCSP response:' | grep -B 17 'Next Update'

exit 0
