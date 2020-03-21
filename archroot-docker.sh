#!/usr/bin/env bash
# Copyright (C) 2020 art of coding UG, Hamburg

if [[ $(id -u) != 0 ]]
then
    echo "Please execute as root"
    exit 1
fi

if [[ $# -lt 1 ]]
then
    echo "usage: $0 <mode>"
    echo "  modes:"
    echo "        install"
    echo "        configure"
    exit 1
fi

set -o nounset
set -o errexit

mode=${1:-}
case "${mode}" in
    install)
        pacman --noconfirm -S docker
        systemctl enable docker
        systemctl restart docker
        pacman --noconfirm -Scc
    ;;
    install-portainer)
        docker volume create portainerdata
        docker run \
            -d \
            -p 127.0.0.1:8000:8000 \
            -p 127.0.0.1:9000:9000 \
            --name=portainer \
            --restart=unless-stopped \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -v portainerdata:/data \
            portainer/portainer
    ;;
    portainer-cert)
        certbot certonly \
            --register-unsafely-without-email --agree-tos --no-eff-email \
            --webroot --webroot-path=/var/lib/letsencrypt \
            --uir \
            --hsts \
            --staple-ocsp --must-staple \
            -n \
            -d portainer.$(hostname -f)
        chmod 644 /etc/letsencrypt/archive/portainer.$(hostname -f)/privkey*.pem
        cat >/srv/http/conf/nginx.d/enabled/portainer.$(hostname -f).conf <<EOF
server {
    listen 443;
    listen [::]:443;
    server_name portainer.$(hostname -f);
    access_log /srv/http/logs/nginx/portainer.$(hostname -f)-tls-access.log main;
    access_log /srv/http/logs/nginx/portainer.$(hostname -f)-tls-scripts.log scripts;
    error_log /srv/http/logs/nginx/portainer.$(hostname -f)-tls-error.log;
    ssl_certificate /etc/letsencrypt/live/portainer.$(hostname -f)/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/portainer.$(hostname -f)/privkey.pem;
    ssl_trusted_certificate /etc/letsencrypt/live/portainer.$(hostname -f)/fullchain.pem;
    ssl_stapling on;
    ssl_stapling_verify on;
    charset utf-8;
    include /srv/http/conf/nginx.d/inc/gzip-std.conf;
    include /srv/http/conf/nginx.d/inc/ssl-std.conf;
    include /srv/http/conf/nginx.d/inc/security-std.conf;
    include /srv/http/conf/nginx.d/inc/location-std.conf;
    root /srv/http/sites/deadend/;
    location / {
        proxy_pass http://127.0.0.1:9000/;
    }
}
EOF
        if [[ ! -d /etc/letsencrypt/archive/portainer.$(hostname -f) ]]
        then
            certbot certonly \
                --register-unsafely-without-email --agree-tos --no-eff-email \
                --webroot --webroot-path=/var/lib/letsencrypt \
                --uir \
                --hsts \
                --staple-ocsp --must-staple \
                -n \
                -d portainer.$(hostname -f)
            chmod 755 /etc/letsencrypt/archive
            chmod 755 /etc/letsencrypt/archive/portainer.$(hostname -f)
            chmod 644 /etc/letsencrypt/archive/portainer.$(hostname -f)/privkey*.pem
            chmod 755 /etc/letsencrypt/live
        fi
        gixy
        systemctl restart nginx
    ;;
esac

exit 0
