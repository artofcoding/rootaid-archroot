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
        pacman --noconfirm -Syu
        pacman --noconfirm -S fcgi
        pacman --noconfirm -S php-fpm
        pacman --noconfirm -S php-apcu
        pacman --noconfirm -S php-gd
        pacman --noconfirm -S php-imap
        pacman --noconfirm -S imagemagick php-imagick
        #pacman --noconfirm -S php-igbinary
        #pacman --noconfirm -S php-memcached
        #pacman --noconfirm -S php-redis
        #-e 's/^[;](extension=igbinary)/\1/' \
        #-e 's/^[;](extension=memcached)/\1/' \
        #-e 's/^[;](extension=redis)/\1/' \
        sed -i'' -E \
            -e 's/^[;](extension=apcu)/\1/' \
            -e 's/^[;](zend_extension=opcache)/\1/' \
            -e 's/^[;](extension=gd)/\1/' \
            -e 's/^[;](extension=iconv)/\1/' \
            -e 's/^[;](extension=mysqli)/\1/' \
            -e 's/^[;](extension=zip)/\1/' \
            /etc/php/php.ini
        #,nr_inodes=5k
        echo "tmpfs  /srv/http/sites/tmp  tmpfs  rw,size=1G,noatime,noexec,nodev,nosuid,uid=http,gid=http,mode=0700  0  0" \
            >>/etc/fstab
        mount /srv/http/sites/tmp
        systemctl enable php-fpm
        systemctl restart php-fpm
        pacman --noconfirm -Scc
        cat >/etc/logrotate.d/php-fpm <<EOF
/srv/http/logs/php-fpm/*.log {
        rotate 30
        daily
        compress
        missingok
        delaycompress
        copytruncate
}
EOF
    ;;
    configure)
        [[ ! -d /srv/http/logs/php-fpm ]] && mkdir /srv/http/logs/php-fpm
        [[ ! -f /etc/php/php-fpm-dist.conf ]] && cp /etc/php/php-fpm.conf /etc/php/php-fpm-dist.conf
        [[ ! -f /etc/php/php.ini ]] && cp /etc/php/php.ini /etc/php/php-dist.ini
        cp php/php-main/php.ini /etc/php/
        cp php/php-main/php-fpm.conf /etc/php/
        cp php/php-main/http-sites.conf /srv/http/conf/php-fpm.d/
        systemctl restart php-fpm
        gixy
        systemctl restart nginx
    ;;
    ping)
        shift ; pool=$1
        SCRIPT_NAME=/ping \
        SCRIPT_FILENAME=/ping \
        REQUEST_METHOD=GET \
        cgi-fcgi -bind -connect /run/php-fpm/${pool}.sock
    ;;
    status)
        shift ; pool=$1
        SCRIPT_NAME=/status \
        SCRIPT_FILENAME=/status \
        REQUEST_METHOD=GET \
        cgi-fcgi -bind -connect /run/php-fpm/${pool}.sock
    ;;
esac

exit 0
