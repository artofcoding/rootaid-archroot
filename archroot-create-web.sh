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

DOMAIN=$1

mkdir -p /srv/http/sites/${DOMAIN}/www
chown http:http /srv/http/sites/${DOMAIN}
chmod 770 /srv/http/sites/${DOMAIN}
chown http:http /srv/http/sites/${DOMAIN}/www
chmod 770 /srv/http/sites/${DOMAIN}/www
cat >/srv/http/sites/${DOMAIN}/www/index.html <<EOF
${DOMAIN}
EOF
chown http:http /srv/http/sites/${DOMAIN}/www/index.html
chmod 660 /srv/http/sites/${DOMAIN}/www/index.html
cat >/srv/http/sites/${DOMAIN}/www/phpinfo.php <<EOF
<?php
phpinfo();
EOF
chown http:http /srv/http/sites/${DOMAIN}/www/phpinfo.php
chmod 660 /srv/http/sites/${DOMAIN}/www/phpinfo.php

cat >/srv/http/conf/nginx.d/enabled/${DOMAIN}.conf <<EOF
server {
    listen 443;
    listen [::]:443;
    set \$service www;
    set \$domain ${DOMAIN};
    server_name ${DOMAIN} www.${DOMAIN};
    access_log /srv/http/logs/nginx/${DOMAIN}-tls-access.log main;
    access_log /srv/http/logs/nginx/${DOMAIN}-tls-scripts.log scripts;
    error_log /srv/http/logs/nginx/${DOMAIN}-tls-error.log;
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    ssl_trusted_certificate /etc/letsencrypt/live/${DOMAIN}/chain.pem;
    ssl_stapling on;
    ssl_stapling_verify on;
    charset utf-8;
    include /srv/http/conf/nginx.d/inc/gzip-std.conf;
    include /srv/http/conf/nginx.d/inc/ssl-std.conf;
    include /srv/http/conf/nginx.d/inc/security-std.conf;
    include /srv/http/conf/nginx.d/inc/location-std.conf;
    #include /srv/http/conf/nginx.d/inc/csp-self.conf;
    root /srv/http/sites/${DOMAIN}/www/;
    # FastCGI _oder_ Joomla
    include /srv/http/conf/nginx.d/inc/location-fastcgi.conf;
    #include /srv/http/conf/nginx.d/inc/location-joomla.conf;
}
EOF

if [[ ! -d /etc/letsencrypt/live/${DOMAIN} ]]
then
    certbot certonly \
        --register-unsafely-without-email --agree-tos --no-eff-email \
        --webroot  --webroot-path=/var/lib/letsencrypt \
        --uir \
        --hsts \
        --staple-ocsp --must-staple \
        -n \
        -d ${DOMAIN} -d www.${DOMAIN}
fi

chmod 755 /etc/letsencrypt/archive
chmod 755 /etc/letsencrypt/archive/${DOMAIN}
chmod 644 /etc/letsencrypt/archive/${DOMAIN}/privkey*.pem
chmod 755 /etc/letsencrypt/live
gixy
systemctl restart nginx

#openssl s_client -connect ${DOMAIN}:443 -servername ${DOMAIN} -status
echo QUIT | openssl s_client -connect ${DOMAIN}:443 -status 2> /dev/null | grep -A 17 'OCSP response:' | grep -B 17 'Next Update'

exit 0
