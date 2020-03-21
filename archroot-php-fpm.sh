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
    ping)
        shift ; pool=$1
        SCRIPT_NAME=/ping \
        SCRIPT_FILENAME=/ping \
        REQUEST_METHOD=GET \
        cgi-fcgi -bind -connect /run/php-fpm/${pool}.sock
    ;;
    status)
        shift ; pool=$1
        SCRIPT_NAME=/status \
        SCRIPT_FILENAME=/status \
        REQUEST_METHOD=GET \
        cgi-fcgi -bind -connect /run/php-fpm/${pool}.sock
    ;;
    install)
        pacman --noconfirm -S fcgi
        pacman --noconfirm -S php-fpm
        pacman --noconfirm -S php-apcu php-memcached php-redis
        pacman --noconfirm -S php-gd
        sed -i'' -E \
            -e 's/^[;](extension=apcu)/\1/' \
            -e 's/^[;](zend_extension=opcache)/\1/' \
            -e 's/^[;](extension=igbinary)/\1/' \
            -e 's/^[;](extension=gd)/\1/' \
            -e 's/^[;](extension=iconv)/\1/' \
            -e 's/^[;](extension=memcached)/\1/' \
            -e 's/^[;](extension=redis)/\1/' \
            -e 's/^[;](extension=mysqli)/\1/' \
            -e 's/^[;](extension=zip)/\1/' \
            /etc/php/php.ini
        #,nr_inodes=5k
        echo "tmpfs  /srv/http/sites/tmp  tmpfs  rw,size=1G,noatime,noexec,nodev,nosuid,uid=http,gid=http,mode=0700  0  0" \
            >>/etc/fstab
        mount /srv/http/sites/tmp
        systemctl enable php-fpm
        systemctl restart php-fpm
        pacman --noconfirm -Scc
    ;;
    configure)
        [[ ! -d /srv/http/logs/php-fpm ]] && mkdir /srv/http/logs/php-fpm
        cat >/srv/http/conf/nginx.d/inc/location-fastcgi.conf <<EOF
location ~* \.php($|/.*\.html$)? {
    include fastcgi.conf;
    fastcgi_split_path_info ^(.+\.php)(/.+)$;
    fastcgi_param PATH_INFO \$fastcgi_path_info;
    fastcgi_index index.php;
    fastcgi_param SCRIPT_FILENAME \$domain/\$service\$fastcgi_script_name;
    # Mitigate https://httpoxy.org/ vulnerabilities
    fastcgi_param HTTP_PROXY "";
    fastcgi_pass unix:/run/php-fpm/http-sites.sock;
    fastcgi_hide_header X-Powered-By;
}
EOF
        cat >/srv/http/conf/nginx.d/inc/location-joomla.conf <<EOF
index index.php index.html;
location / {
    try_files \$uri \$uri/ /index.php?\$args;
}
error_page 404 /index.php;
if (\$query_string ~ "base64_encode[^(]*\([^)]*\)") {
    return 404;
}
if (\$query_string ~* "(<|%3C)([^s]*s)+cript.*(>|%3E)") {
    return 404;
}
if (\$query_string ~ "GLOBALS(=|\[|\%[0-9A-Z]{0,2})") {
    return 404;
}
if (\$query_string ~ "_REQUEST(=|\[|\%[0-9A-Z]{0,2})") {
    return 404;
}
if (!-e \$request_filename) {
    rewrite ^(.*)$ /index.php break;
}
location ~* /(images|joomlatools_files|cache|media|logs|tmp)/.*\.(txt|html|php|pl|py|jsp|asp|sh|cgi)$ {
    return 404;
}
location ~* /configuration*.php {
    return 404;
}
location ~* ^/(bin|cli|logs|files_logs|files_temp|includes|modules|language|layouts|libraries|plugins) {
    return 404;
}
location ~* \.(js|css)$ {
    try_files \$uri =404;
    expires 24h;
}
location ~* \.(png|jpe?g|gif|ico)$ {
    try_files \$uri /images/\$uri =404;
    expires 1d;
}
location ~* \.(pdf|txt|xml)$ {
    try_files \$uri =404;
    expires 1d;
}
include /srv/http/conf/nginx.d/inc/location-fastcgi.conf;
EOF
        [[ ! -f /etc/php/php-fpm-dist.conf ]] && cp /etc/php/php-fpm.conf /etc/php/php-fpm-dist.conf
        cat >/etc/php/php-fpm.conf <<EOF
[global]
pid = /run/php-fpm/php-fpm.pid
error_log = /srv/http/logs/php-fpm/php-fpm.error.log
log_level = notice
log_limit = 4096
log_buffering = yes
emergency_restart_threshold = 10
emergency_restart_interval = 1m
process_control_timeout = 10s
process.max = 128
daemonize = yes
rlimit_files = 1024
rlimit_core = 0
;events.mechanism =
systemd_interval = 10
;include=/etc/php/php-fpm.d/*.conf
include=/srv/http/conf/php-fpm.d/*.conf
EOF
        # https://haydenjames.io/php-fpm-tuning-using-pm-static-max-performance/
        cat >/srv/http/conf/php-fpm.d/http-sites.conf <<EOF
[http-sites]
prefix = /srv/http/sites
user = http
group = http
listen = /run/php-fpm/\$pool.sock
listen.owner = http
listen.group = http
listen.mode = 0660
pm = static
pm.max_children = 16
pm.max_requests = 512
pm.status_path = /status
ping.path = /ping
ping.response = pong
access.log = /srv/http/logs/php-fpm/\$pool.access.log
access.format = "%R - %u %t \"%m %r%Q%q\" %s %f %{mili}d %{kilo}M %C%%"
slowlog = /srv/http/logs/php-fpm/\$pool.slow.log
chroot = \$prefix
catch_workers_output = no
security.limit_extensions = .php .html
env[HOSTNAME] = \$HOSTNAME
env[PATH] = /usr/local/bin:/usr/bin:/bin
env[TMP] = /tmp
env[TMPDIR] = /tmp
env[TEMP] = /tmp
php_admin_value[error_log] = /srv/http/logs/php-fpm/$pool.php-error.log
php_admin_flag[log_errors] = on
php_admin_value[memory_limit] = 512M
php_admin_value[open_basedir] = "/"
php_admin_value[session.save_path] = "0;0600/tmp"
php_admin_value[session.serialize_handler] = php_serialize
php_admin_value[session.sid_length] = 32
php_admin_value[session.sid_bits_per_character] = 5
; nicht aktivieren php_admin_value[cgi.fix_pathinfo] = 0
EOF
        systemctl restart php-fpm
        gixy
        systemctl restart nginx
    ;;
esac

exit 0
