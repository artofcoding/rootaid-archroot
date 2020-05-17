#!/usr/bin/env bash
# Copyright (C) 2020 art of coding UG, Hamburg

if [[ $(id -u) != 0 ]]
then
    echo "Please execute as root"
    exit 1
fi

curl -L -o /srv/http/mod_files.sh https://raw.githubusercontent.com/php/php-src/master/ext/session/mod_files.sh
chmod 555 /srv/http/mod_files.sh
mkdir -p /srv/http/sites/tmp
rm -rf /srv/http/sites/tmp/*
/srv/http/mod_files.sh /srv/http/sites/tmp 4 5

systemctl restart php-fpm

exit 0
