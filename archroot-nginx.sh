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
        pushd /srv/http/conf >/dev/null
        git clone https://github.com/h5bp/server-configs-nginx.git
        popd >/dev/null
        echo "0 0 * * * ( pushd /srv/http/conf/server-configs-nginx && git reset --hard && git pull )" | crontab -
        cat >/etc/sysctl.d/90-nginx.conf <<EOF
net.core.somaxconn=8192
EOF
        sysctl --system
        pacman --noconfirm -S nginx-mainline
        systemctl enable nginx
        cat >/etc/logrotate.d/nginx <<EOF
/var/log/nginx/*.log {
        rotate 30
        daily
        compress
        missingok
        delaycompress
        copytruncate
}
/srv/http/logs/nginx/*.log {
        rotate 30
        daily
        compress
        missingok
        delaycompress
        copytruncate
}
EOF
        pacman --noconfirm -S gixy
        pacman --noconfirm -S certbot certbot-nginx
        pacman --noconfirm -Scc
        ( crontab -l ; echo "0 4 * * FRI ( certbot renew )" ) | crontab -
    ;;
    configure)
        [[ ! -d /srv/http/logs/nginx ]] && mkdir /srv/http/logs/nginx
        cp /usr/local/etc/archroot/nginx/nginx.conf /etc/nginx/
        cp /usr/local/etc/archroot/nginx/inc/*.conf /srv/http/conf/nginx.d/inc/
        mkdir -p /srv/http/sites/deadend/
        cp -r /usr/local/etc/archroot/sites/deadend/ /srv/http/sites/
        chmod 555 /srv/http/sites/deadend/
        find /srv/http/sites/deadend/ -type f -print0 | xargs -r -0 chmod 444
        [[ ! -d /srv/http/conf/nginx.d/disabled ]] && mkdir /srv/http/conf/nginx.d/disabled
        [[ ! -d /srv/http/conf/nginx.d/enabled ]] && mkdir /srv/http/conf/nginx.d/enabled
        cp /usr/local/etc/archroot/nginx/dynamic.conf /srv/http/conf/nginx.d/disabled/
        cp /usr/local/etc/archroot/nginx/tlsredirect.conf /srv/http/conf/nginx.d/enabled/
        gixy
        nginx -s reload
        hostname="$(hostname -f)"
        cat /usr/local/etc/archroot/nginx/tls-main.tmpl.conf \
            | sed -e "s#HOSTNAME#${hostname}#g" \
            >/srv/http/conf/nginx.d/enabled/${hostname}.conf
        certbot certonly \
            --register-unsafely-without-email --agree-tos --no-eff-email \
            --webroot --webroot-path=/var/lib/letsencrypt \
            --uir \
            --hsts \
            --staple-ocsp --must-staple \
            -n \
            -d ${hostname}
        chmod 644 /etc/letsencrypt/archive/${hostname}/privkey*.pem
        gixy
        nginx -s reload
    ;;
esac

exit 0
