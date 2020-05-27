ARG NGINX_RELEASE
FROM nginx:${NGINX_RELEASE} AS base
LABEL maintainer="Ralf Bensmann <ralf@art-of-coding.eu>"
LABEL vendor="Art of Coding UG"

ENV TZ Europe/Berlin
ENV LANG en_US.UTF-8

RUN apk update \
    && apk --no-cache add \
        tzdata \
        curl \
        git \
        nginx-mod-http-headers-more \
        openssl \
        certbot-nginx \
    && cp /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo "${TZ}" >/etc/timezone \
    && rm /etc/nginx/conf.d/default.conf* \
    && adduser -u 82 -D -S -G www-data www-data \
    && echo "0 0 * * WED,SUN certbot renew" | crontab -

FROM base
COPY nginx.conf /etc/nginx/
COPY tlsredirect.conf /etc/nginx/conf.d/
VOLUME ["/etc/nginx", "/etc/letsencrypt"]
CMD ["nginx"]
