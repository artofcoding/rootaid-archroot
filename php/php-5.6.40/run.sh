#!/usr/bin/env bash
# Copyright (C) 2020 art of coding UG, Hamburg

if [[ $(id -u) != 0 ]]
then
    echo "Please execute as root"
    exit 1
fi

set -o nounset
set -o errexit

docker build -t medienhof/php:5.6.40-fpm .
if [[ $? -gt 0 ]]
then
    echo "Docker Image wurde nicht erfolgreich erstellt"
    exit 1
fi

cp php-5.6.40.conf /srv/http/conf/php-fpm.d/

CONTAINER="php-5640"
if [[ x"$(docker ps -aq --filter name=${CONTAINER})" != x"" ]]
then
    echo "Removing existing container"
    docker rm -f ${CONTAINER}
fi

hostip="$(ip route | grep docker0 | awk '{print $9}')"
docker run \
    -d \
    --restart unless-stopped \
    --name ${CONTAINER} \
    --mount type=bind,source=/run/php-fpm,destination=/run/php-fpm \
    --mount type=bind,source=/srv/http/conf/php-fpm.d/php-5.6.40.conf,destination=/srv/http/conf/php-fpm.d/php-5.6.40.conf,readonly \
    --mount type=bind,source=/srv/http/sites,destination=/srv/http/sites \
    --mount type=bind,source=/srv/http/logs/php-fpm,destination=/srv/http/logs/php-fpm \
    --mount type=tmpfs,destination=/srv/http/sites/tmp,tmpfs-size=134217728 \
    --add-host=host.docker.internal:${hostip} \
    --add-host=mariadb.local:${hostip} \
    medienhof/php:5.6.40-fpm "$*"
if [[ $? -gt 0 ]]
then
    echo "Docker Container wurde nicht erfolgreich erstellt"
    exit 1
fi

exit 0
