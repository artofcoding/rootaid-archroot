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
    exit 1
fi

set -o nounset
set -o errexit

mode=${1:-}
case "${mode}" in
    install)
        mkdir /srv/http/mariadb
        # https://wiki.archlinux.de/title/MariaDB
        pacman --noconfirm -S mariadb
        sed -i'' \
            -e '/^\[mysqld\]/a datadir=/srv/http/mariadb' \
            /etc/my.cnf.d/server.cnf
        mysql_install_db --user=mysql --basedir=/usr --datadir=/srv/http/mariadb
        systemctl restart mariadb
        systemctl enable mariadb
        pw="$(pwgen -B 12 -n 1)"
        /usr/bin/mysqladmin -u root password "${pw}"
        echo "MariaDB root password is '${pw}'"
    ;;
esac

exit 0
