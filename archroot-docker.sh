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
    echo "        install-php"
    echo "        install-portainer"
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
        pacman --noconfirm -S docker-compose
        pacman --noconfirm -Scc
        cat >/etc/logrotate.d/docker <<EOF
/var/lib/docker/containers/*/*.log {
        rotate 30
        daily
        compress
        missingok
        delaycompress
        copytruncate
}
EOF
    ;;
    install-php)
        pushd php >/dev/null
        for dir in php-*
        do
            pushd ${dir} >/dev/null \
                && ./run.sh \
                && popd >/dev/null
        done
        popd >/dev/null
    ;;
    install-portainer)
        docker volume create portainerdata
        docker run \
            -d \
            --restart unless-stopped \
            --name portainer \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -v portainerdata:/data \
            -p 127.0.0.1:8000:8000 \
            -p 127.0.0.1:9000:9000 \
            portainer/portainer
    ;;
    portainer-cert)
        hostname="$(hostname -f)"
        certbot certonly \
            --register-unsafely-without-email --agree-tos --no-eff-email \
            --webroot --webroot-path=/var/lib/letsencrypt \
            --uir \
            --hsts \
            --staple-ocsp --must-staple \
            -n \
            -d portainer.${hostname}
        chmod 644 /etc/letsencrypt/archive/portainer.${hostname}/privkey*.pem
        cat nginx/disabled/portainer.tmpl.conf \
            | sed -e "s#HOSTNAME#${hostname}#g" \
            >/srv/http/conf/nginx.d/enabled/portainer.${hostname}.conf
        if [[ ! -d /etc/letsencrypt/archive/portainer.${hostname} ]]
        then
            certbot certonly \
                --register-unsafely-without-email --agree-tos --no-eff-email \
                --webroot --webroot-path=/var/lib/letsencrypt \
                --uir \
                --hsts \
                --staple-ocsp --must-staple \
                -n \
                -d portainer.${hostname}
            chmod 755 /etc/letsencrypt/archive
            chmod 755 /etc/letsencrypt/archive/portainer.${hostname}
            chmod 644 /etc/letsencrypt/archive/portainer.${hostname}/privkey*.pem
            chmod 755 /etc/letsencrypt/live
        fi
        gixy
        nginx -s reload
    ;;
esac

exit 0
