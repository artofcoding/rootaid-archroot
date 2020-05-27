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
    echo "  storage:"
    echo "        setup-storage"
    echo "        setup-tank"
    echo "        setup-srvhttp"
    echo "  permissions:"
    echo "        perms"
    exit 1
fi

set -o nounset
set -o errexit

mode=${1:-}
case "${mode}" in
    install)
        pacman --noconfirm -Sy archlinux-keyring
        pacman --noconfirm -Syu
        pacman --noconfirm -S inetutils
        pacman --noconfirm -S man man-pages
        pacman --noconfirm -S pacman-contrib
        systemctl enable paccache.timer
        pacman --noconfirm -S lvm2
        pacman --noconfirm -S vi vim
        pacman --noconfirm -S pwgen
        pacman --noconfirm -S git
        pacman --noconfirm -S ca-certificates ca-certificates-mozilla ca-certificates-utils
        pacman --noconfirm -S logrotate
        systemctl enable logrotate.timer
        pacman --noconfirm -Scc
        timedatectl set-timezone Europe/Berlin
        echo "Please reboot"
    ;;
    setup-storage)
        sfdisk --dump /dev/sda >sda.dump
        # TODO Nur, wenn sda4 nicht existiert
        echo ",,30" | sfdisk --force -a /dev/sda
        echo "Please reboot"
    ;;
    setup-tank)
        pvcreate /dev/sda4
        vgcreate tank /dev/sda4
        # TODO Nur, wenn LV docker nicht existiert
        lvcreate -L1G -n docker tank
        mkfs.ext4 /dev/tank/docker
        mkdir /var/lib/docker
        export $(blkid -o export /dev/tank/docker)
        cat >>/etc/fstab <<EOF
UUID=$UUID  /var/lib/docker  ext4  rw,noatime,noexec,nodev,nosuid  0  0
EOF
        mount /var/lib/docker
        # TODO Nur, wenn LV srvhttp nicht existiert
        lvcreate -L1G -n srvhttp tank
        mkfs.ext4 /dev/tank/srvhttp
        export $(blkid -o export /dev/tank/srvhttp)
        cat >>/etc/fstab <<EOF
UUID=$UUID  /srv/http  ext4  rw,noatime,noexec,nodev,nosuid  0  0
EOF
        mount /srv/http
    ;;
    setup-srvhttp)
        mkdir /srv/http/conf
        mkdir /srv/http/conf/nginx.d
        mkdir /srv/http/conf/nginx.d/inc
        if [[ -f /etc/nginx/nginx.conf ]]
        then
            mv /etc/nginx/nginx.conf /srv/http/conf
            ln -s /srv/http/conf/nginx.conf /etc/nginx
        fi
        mkdir /srv/http/conf/php-fpm.d
        mkdir /srv/http/logs
        mkdir /srv/http/sites
        mkdir /srv/http/sites/tmp
        mkdir /srv/http/ssl
    ;;
    perms)
        # nginx
        chown root:root /etc/nginx/nginx.conf
        chmod 600 /etc/nginx/nginx.conf
        # directories and files
        find /srv/http/conf -print0 | xargs -r -0 chown root:root
        find /srv/http/conf -type d -print0 | xargs -r -0 chmod 555
        find /srv/http/conf -type f -print0 | xargs -r -0 chmod 644
        # ssl
        chown root:root /srv/http/ssl
        chmod 755 /srv/http/ssl
        find /srv/http/ssl/* -type f -print0 | xargs -r -0 chmod 440
        # logs
        chown http:http /srv/http/logs
        chmod 750 /srv/http/logs
        # sites
        chown root:root /srv/http/sites
        chmod 755 /srv/http/sites
        # sites/deadend
        chown root:root /srv/http/sites/deadend
        chmod 555 /srv/http/sites/deadend
        # sites/*
        find /srv/http/sites/* -print0 | xargs -r -0 chown http:http
        find /srv/http/sites/* -type d -print0 | xargs -r -0 chmod 750
        find /srv/http/sites/* -type f -print0 | xargs -r -0 chmod 640
        # tmp
        chown http:http /srv/http/sites/tmp
        chmod 0700 /srv/http/sites/tmp
        find /srv/http/sites/tmp -type f -print0 | xargs -r -0 chmod 600
        # custom
        exec "$(dirname $0)/$(hostname -f)-perms.sh"
    ;;
esac

exit 0
