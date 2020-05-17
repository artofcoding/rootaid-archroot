FROM php:5.6.40-fpm AS base
RUN apt-get -y update
RUN apt-get -y install procps less vim
RUN apt-get -y install curl libcurl3 libcurl3-openssl-dev
RUN apt-get -y install imagemagick
RUN apt-get -y install libmagickwand-dev --no-install-recommends
RUN apt-get -y install libpng-dev 
RUN apt-get -y install libjpeg62-turbo-dev
RUN apt-get -y install libzip-dev
RUN apt-get -y install libc-client-dev
RUN apt-get -y install libkrb5-dev
RUN apt-get -y install libldap2-dev
RUN rm -rf /var/lib/apt/lists/*

FROM base AS php
RUN docker-php-ext-install curl
RUN docker-php-ext-install exif
RUN docker-php-ext-configure gd --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install gd
RUN printf "\n" | pecl install imagick \
    && docker-php-ext-enable imagick
RUN docker-php-ext-configure imap --with-kerberos --with-imap-ssl \
    && docker-php-ext-install imap
#RUN docker-php-ext-install ldap
RUN docker-php-ext-install mbstring
RUN docker-php-ext-install mysql
RUN docker-php-ext-install mysqli
RUN docker-php-ext-install pdo pdo_mysql
RUN docker-php-ext-install zip

FROM php
ADD php-fpm.conf /usr/local/etc/
ADD php.ini /usr/local/etc/php/
VOLUME ["/run/php-fpm", "/srv/http/conf/php-fpm.d", "/srv/http/sites", "/srv/http/sites/tmp", "/srv/http/logs"]
WORKDIR /srv/http
ADD docker-php-entrypoint /usr/local/bin
ENTRYPOINT ["docker-php-entrypoint"]
CMD ["php-fpm"]
