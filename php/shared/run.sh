#!/usr/bin/env bash
# Copyright (C) 2020 art of coding UG, Hamburg

if [[ $(id -u) != 0 ]]
then
    echo "Please execute as root"
    exit 1
fi

if [[ $# != 1 ]]
then
    echo "usage: $0 <PHP version>"
    exit 1
fi

set -o nounset
set -o errexit

PHP_VERSION=$1

cat php-fpm.conf \
    | sed -e "s#PHP_VERSION#${PHP_VERSION}#g" \
    > php-fpm-${PHP_VERSION}.conf
docker build \
    --build-arg PHP_VERSION=${PHP_VERSION} \
    -t medienhof/php:${PHP_VERSION}-fpm \
    .
if [[ $? -gt 0 ]]
then
    echo "Docker Image wurde nicht erfolgreich erstellt"
    exit 1
fi

cp php${PHP_VERSION}.conf /srv/http/conf/php-fpm.d/

CONTAINER="php-${PHP_VERSION//./-}"
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
    --mount type=bind,source=/srv/http/conf/php-fpm.d/php-${PHP_VERSION}.conf,destination=/srv/http/conf/php-fpm.d/php-${PHP_VERSION}.conf,readonly \
    --mount type=bind,source=/srv/http/sites,destination=/srv/http/sites \
    --mount type=tmpfs,destination=/srv/http/sites/tmp,tmpfs-size=134217728 \
    --mount type=bind,source=/srv/http/logs/php-fpm,destination=/srv/http/logs/php-fpm \
    --add-host=host.docker.internal:${hostip} \
    --add-host=mariadb.local:${hostip} \
    medienhof/php:${PHP_VERSION}-fpm "$*"
if [[ $? -gt 0 ]]
then
    echo "Docker Container wurde nicht erfolgreich erstellt"
    exit 1
fi
cat /usr/local/etc/archroot/php/shared/location-fastcgi.tmpl.conf \
    | sed -e "s#PHP_VERSION#${PHP_VERSION}#g" \
    >/srv/http/conf/nginx/inc/location-fastcgi-${PHP_VERSION}.conf
[[ -f php-fpm-${PHP_VERSION}.conf ]] && rm php-fpm-${PHP_VERSION}.conf
cat location-fastcgi.tmpl.conf \
    | sed -e "s#PHP_VERSION#${PHP_VERSION}#g" \
    >/srv/http/conf/nginx/inc/location-fastcgi-php-${PHP_VERSION}.conf

exit 0
