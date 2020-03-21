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
        pushd /srv/http/conf >/dev/null
        git clone https://github.com/h5bp/server-configs-nginx.git
        popd >/dev/null
        echo "0 0 * * * ( pushd /srv/http/conf/server-configs-nginx && git reset --hard && git pull )" | crontab -
        cat >/etc/sysctl.d/90-nginx.conf <<EOF
net.core.somaxconn=8192
EOF
        sysctl --system
        pacman --noconfirm -S nginx-mainline
        systemctl enable nginx
        pacman --noconfirm -S gixy
        pacman --noconfirm -S certbot certbot-nginx
        ( crontab -l ; echo "0 4 * * FRI ( certbot renew )" ) | crontab -
    ;;
    configure)
        [[ ! -d /srv/http/logs/nginx ]] && mkdir /srv/http/logs/nginx
        cat >/etc/nginx/nginx.conf <<EOF
user http;
worker_processes auto;
#pid /run/nginx.pid;
error_log /srv/http/logs/nginx/error.log info;

events {
    worker_connections  8000;
}

http {

    include mime.types;
    default_type  application/octet-stream;

    types_hash_max_size 4096;
    server_names_hash_bucket_size 128;
    sendfile on;
    sendfile_max_chunk 1m;
    tcp_nopush on;
    #tcp_nodelay on;
    keepalive_timeout 65;

    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"';

    log_format scripts '\$request > \$document_root\$fastcgi_script_name';

    # Cloudflare 1.1.1.1, Cisco OpenDNS, Google DNS, local
    resolver [2606:4700:4700::1111] [2606:4700:4700::1001] 1.1.1.1 1.0.0.1
             [2620:119:35::35] [2620:119:53::53] 208.67.222.222 208.67.220.220
             [2001:4860:4860::8888] [2001:4860:4860::8844] 8.8.8.8 8.8.4.4
             [::1] 127.0.0.1
             valid=60s;
    resolver_timeout 1s;

    server_tokens off;

    include /srv/http/conf/nginx.d/enabled/*.conf;

}
EOF
        cat >/srv/http/conf/nginx.d/inc/gzip-std.conf <<EOF
gzip on;
gzip_types text/plain
           text/css
           application/json
           text/javascript application/javascript application/x-javascript
           text/xml application/xml application/xhtml+xml application/xml+rss;
gzip_proxied no-cache no-store no_last_modified private expired auth;
gzip_min_length 256;
gzip_comp_level 6;
EOF
        cat >/srv/http/conf/nginx.d/inc/ssl-std.conf <<EOF
#include /etc/letsencrypt/options-ssl-nginx.conf;
#ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
ssl_protocols TLSv1.3 TLSv1.2;
#ssl_ciphers EECDH+AESGCM:EDH+AESGCM;
#ssl_prefer_server_ciphers on;
#ssl_ecdh_curve secp384r1;
ssl_session_timeout 10m;
ssl_session_cache shared:SSL:10m;
ssl_session_tickets off;
#ssl_session_ticket_key /etc/nginx/ssl_session_ticket.key;
#ssl_stapling on;
#ssl_stapling_verify on;
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload";
EOF
        cat >/srv/http/conf/nginx.d/inc/security-std.conf <<EOF
add_header X-Powered-By "";
add_header Referrer-Policy same-origin;
add_header X-Frame-Options DENY;
add_header X-Content-Type-Options nosniff;
add_header X-XSS-Protection "1; mode=block;";
add_header Content-Security-Policy "upgrade-insecure-requests;";
EOF
        cat >/srv/http/conf/nginx.d/inc/csp-self.conf <<EOF
add_header Content-Security-Policy "upgrade-insecure-requests; default-src 'self';";
add_header X-Content-Security-Policy "default-src 'self';";
add_header X-WebKit-CSP "default-src 'self';";
EOF
        cat >/srv/http/conf/nginx.d/inc/expires.conf <<EOF
map \$sent_http_content_type \$expires {
    default                    1d;
    text/html                  epoch;
    text/css                   max;
    application/javascript     max;
    ~image/                    max;
}
expires \$expires;
EOF
        cat >/srv/http/conf/nginx.d/inc/location-std.conf <<EOF
location ~ /\. {
    deny all;
}
location = /robots.txt {
    allow all;
    log_not_found off;
    access_log off;
}
location = /favicon.ico {
    allow all;
    log_not_found off;
    access_log off;
}
EOF
        mkdir -p /srv/http/sites/deadend/
        cat >/srv/http/sites/deadend/index.html <<EOF
<!DOCTYPE>
<html>
<head>
    <title>Dead End</title>
</head>
<body>
    <p>Yo, dead end.</p>
</body>
</html>
EOF
        chmod 555 /srv/http/sites/deadend/
        chmod 444 /srv/http/sites/deadend/index.html
        cat >/srv/http/conf/nginx.d/enabled/tlsredirect.conf <<EOF
server {
    listen 80 default_server backlog=4096;
    listen [::]:80 default_server backlog=4096;
    server_name _;
    location ^~ /.well-known/acme-challenge/ {
        root /var/lib/letsencrypt/;
        allow all;
        default_type "text/plain";
        try_files \$uri =404;
    }
    location / {
        return 301 https://\$host\$request_uri;
    }
}
EOF
        gixy
        systemctl restart nginx
        cat >/srv/http/conf/nginx.d/disabled/$(hostname -f).conf <<EOF
server {
    listen 443 ssl default_server backlog=4096;
    listen [::]:443 ssl default_server backlog=4096;
    server_name medienhof11.rootaid.de;
    access_log /srv/http/logs/nginx/$(hostname -f)-tls-access.log main;
    access_log /srv/http/logs/nginx/$(hostname -f)-tls-scripts.log scripts;
    error_log /srv/http/logs/nginx/$(hostname -f)-tls-error.log;
    ssl_certificate /etc/letsencrypt/live/$(hostname -f)/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$(hostname -f)/privkey.pem;
    ssl_trusted_certificate /etc/letsencrypt/live/$(hostname -f)/fullchain.pem;
    ssl_stapling on;
    ssl_stapling_verify on;
    charset utf-8;
    include /srv/http/conf/nginx.d/inc/gzip-std.conf;
    include /srv/http/conf/nginx.d/inc/ssl-std.conf;
    include /srv/http/conf/nginx.d/inc/security-std.conf;
    include /srv/http/conf/nginx.d/inc/location-std.conf;
    include /srv/http/conf/nginx.d/inc/csp-self.conf;
    root /srv/http/sites/deadend/;
}
EOF
        cat >/srv/http/conf/nginx.d/disabled/dynamic.conf <<EOF
server {
    listen 443;
    listen [::]:443;
    server_name ~^(<service>.+?)\.(?<domain>.+)$;
    access_log /srv/http/logs/nginx/\$ssl_server_name-tls-access.log main;
    access_log /srv/http/logs/nginx/\$ssl_server_name-tls-scripts.log scripts;
    error_log /srv/http/logs/nginx/\$ssl_server_name-tls-error.log;
    ssl_certificate /etc/letsencrypt/live/\$ssl_server_name/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/\$ssl_server_name/privkey.pem;
    ssl_stapling off;
    ssl_stapling_verify off;
    charset utf-8;
    include /srv/http/conf/nginx.d/inc/gzip-std.conf;
    include /srv/http/conf/nginx.d/inc/ssl-std.conf;
    include /srv/http/conf/nginx.d/inc/security-std.conf;
    include /srv/http/conf/nginx.d/inc/location-std.conf;
    include /srv/http/conf/nginx.d/inc/csp-self.conf;
    root /srv/http/sites/\$domain/\$service/;
    # FastCGI _oder_ Joomla
    #include /srv/http/conf/nginx.d/inc/location-fastcgi.conf;
    #include /srv/http/conf/nginx.d/inc/location-joomla.conf;
}
EOF
        certbot certonly \
            --register-unsafely-without-email --agree-tos --no-eff-email \
            --webroot --webroot-path=/var/lib/letsencrypt \
            --uir \
            --hsts \
            --staple-ocsp --must-staple \
            -n \
            -d $(hostname -f)
        chmod 644 /etc/letsencrypt/archive/$(hostname -f)/privkey*.pem
        gixy
        systemctl restart nginx
    ;;
esac

exit 0
