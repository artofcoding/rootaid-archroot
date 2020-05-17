#!/usr/bin/env bash
# Copyright (C) 2020 art of coding UG, Hamburg

set -o nounset
set -o errexit

docker build -t medienhof/php:7.3.16-fpm .
if [[ $? -gt 0 ]]
then
    echo "Docker Image wurde nicht erfolgreich erstellt"
    exit 1
fi
# TODO --tmpfs --read-only
hostip="$(ip route | grep docker0 | awk '{print $9}')"
docker run \
    -d \
    --restart unless-stopped \
    --name php73 \
    -v /run/php-fpm:/run/php-fpm:rw \
    -v /srv/http/conf/php-fpm.d/php-7.3.16.conf:/srv/http/conf/php-fpm.d/php-7.3.16.conf:ro \
    -v /srv/http/sites:/srv/http/sites:rw \
    -v /srv/http/logs/php-fpm:/srv/http/logs/php-fpm:rw \
    --add-host=host.docker.internal:${hostip} \
    --add-host=mariadb.local:${hostip} \
    medienhof/php:7.3.16-fpm "$*"
if [[ $? -gt 0 ]]
then
    echo "Docker Container wurde nicht erfolgreich erstellt"
    exit 1
fi

exit 0
