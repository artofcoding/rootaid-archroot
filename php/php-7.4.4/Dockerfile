ARG PHP_VERSION
FROM php:7.4.4-fpm AS base
RUN apt-get -y update
RUN apt-get -y install procps less vim
RUN apt-get -y install curl libcurl4 libcurl4-openssl-dev
RUN apt-get -y install imagemagick
RUN apt-get -y install libmagickwand-dev --no-install-recommends
RUN apt-get -y install libpng-dev libzip-dev
RUN apt-get -y install libc-client-dev libkrb5-dev
RUN apt-get -y install libldap2-dev
RUN rm -rf /var/lib/apt/lists/*

FROM base AS php
RUN docker-php-ext-install curl
RUN docker-php-ext-install exif
RUN docker-php-ext-configure gd --with-jpeg \
    && docker-php-ext-install gd
RUN printf "\n" | pecl install imagick \
    && docker-php-ext-enable imagick
RUN docker-php-ext-configure imap --with-kerberos --with-imap-ssl \
    && docker-php-ext-install imap
RUN docker-php-ext-install ldap
RUN docker-php-ext-install mbstring
RUN docker-php-ext-install mysqli
RUN docker-php-ext-install pdo pdo_mysql
RUN docker-php-ext-install zip

FROM php
ADD php-fpm-7.4.4.conf /usr/local/etc/php-fpm.conf
ADD php-7.4.4.ini /usr/local/etc/php/php.ini
VOLUME ["/run/php-fpm", "/srv/http/conf/php-fpm.d", "/srv/http/sites", "/srv/http/logs"]
WORKDIR /srv/http
ADD docker-php-entrypoint /usr/local/bin
ENTRYPOINT ["docker-php-entrypoint"]
CMD ["php-fpm"]
