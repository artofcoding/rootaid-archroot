#!/usr/bin/env bash
# Copyright (C) 2020 art of coding UG, Hamburg

if [[ $(id -u) != 0 ]]
then
    echo "Please execute as root"
    exit 1
fi

if [[ $# != 1 ]]
then
    echo "usage: $0 <domain>"
    echo "  e.g. $0 medienhof.de"
    exit 1
fi

set -o nounset
set -o errexit

EMAIL="${EMAIL:-"--register-unsafely-without-email --no-eff-email"}"
DOMAIN=$1

if [[ ! -d /srv/http/sites/${DOMAIN}/www ]]
then
    mkdir -p /srv/http/sites/${DOMAIN}/www
    cat /usr/local/etc/archroot/sites/tmpl/index.html \
        | sed -e "s#DOMAIN#${DOMAIN}#g" \
        > /srv/http/sites/${DOMAIN}/www/index.html
    cp /usr/local/etc/archroot/sites/tmpl/phpinfo.php /srv/http/sites/${DOMAIN}/www
    cp /usr/local/etc/archroot/sites/tmpl/robots.txt /srv/http/sites/${DOMAIN}/www
fi

chown -R http:http /srv/http/sites/${DOMAIN}
find /srv/http/sites/${DOMAIN} -type d -print0 | xargs -r -0 chmod 755
find /srv/http/sites/${DOMAIN} -type f -print0 | xargs -r -0 chmod 644

cat /usr/local/etc/nginx/tls-domain.tmpl.conf \
    | sed -e "s#DOMAIN#${DOMAIN}#g" \
    >/srv/http/conf/nginx.d/enabled/${DOMAIN}.conf
if [[ ! -d /etc/letsencrypt/live/${DOMAIN} ]]
then
    archroot-certonly.sh -d ${DOMAIN} -d www.${DOMAIN}
fi
gixy
sudo nginx -s reload

#openssl s_client -connect ${DOMAIN}:443 -servername ${DOMAIN} -status
echo QUIT | openssl s_client -connect ${DOMAIN}:443 -status 2> /dev/null | grep -A 17 'OCSP response:' | grep -B 17 'Next Update'

exit 0
