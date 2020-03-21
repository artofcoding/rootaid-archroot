# archroot

This document describes setup of ArchLinux virtual server with database, web server Nginx, Lets Encrypt and PHP (F)astCGI (P)rocess (M)anager.

The following is assumed:

* Operating system is installed on its own partition (e.g. 8 GB in size)
* Rest of disk is not partitioned

ATTENTION:

* Execute commands in the order shown
* Do not execute commands more than once,
  * if something fails, correct it by yourself

## Filesystem

    /srv/http
    ├── conf
    │   ├── nginx.d
    │   │   ├── disabled
    │   │   ├── enabled
    │   │   │   └── example.org.conf
    │   │   └── inc
    │   ├── php-fpm.d
    │   │   └── http-sites.conf
    │   └── server-configs-nginx
    ├── logs
    │   ├── nginx
    │   └── php-fpm
    ├── mariadb
    └── sites
        ├── deadend
        ├── example.org
        │   └── www
        └── tmp

## TLS

TODO DNS CAA

## Prerequisites

Copy all scripts to virtual server:

    scp *.sh virtual-server:/usr/local/bin

## Software Packages

Initialize system, install software:

    sudo archroot.sh install

## Storage

1. Use remaining space on disk

        sudo archroot.sh setup-storage

1. Create logical volumes for Docker and web applications:

        sudo archroot.sh setup-tank

1. Initialize filesystem under /srv/http

        sudo archroot.sh setup-srvhttp

## Database

MariaDB

    sudo archroot-mariadb.sh install

## Web Server

nginx

    sudo archroot-nginx.sh install
    sudo archroot-nginx.sh configure

## PHP

PHP FPM:

    sudo archroot-php-fpm.sh install
    sudo archroot-php-fpm.sh configure

### Joomla

FPM Pool: http-sites

configuration.php / Database configuration

    public $host = '127.0.0.1';

configuration.php / Logging

    public $log_path = '/example.org/www/administrator/logs';

configuration.php / Temporary files

    public $tmp_path = '/tmp';

or

    public $tmp_path = '/example.org/www/tmp';

### Test

    SCRIPT_NAME=/example.org/www/index.php/testpage.html \
    SCRIPT_FILENAME=/example.org/www/index.php/testpage.html \
    HTTP_HOST=www.example.org \
    REQUEST_METHOD=GET \
    cgi-fcgi -bind -connect /run/php-fpm/php-fpm/http-sites.sock

## Docker

    sudo archroot-docker.sh install

### Portainer

    sudo archroot-docker.sh install-portainer

Execute the following if:

* nginx and Lets Encrypt are installed
* You want to protect Portainer through https

    sudo archroot-docker.sh portainer-cert

## Permissions

    sudo archroot.sh perms

## Resources

* [Google PageSpeed](https://developers.google.com/speed/pagespeed/insights/)
* [GTMetrix](https://gtmetrix.com/)
* [Pingdom](https://tools.pingdom.com/)
* [Security Headers](https://securityheaders.com/)
* [Qualys SSL Labs](https://www.ssllabs.com/ssltest/analyze.html)
* [WebPageTest](https://www.webpagetest.org/)
* [dnsperf.com](https://www.dnsperf.com/#!dns-resolvers,Europe)

### Nginx

* https://www.nginx.com/resources/wiki/start/
* https://www.nginx.com/resources/wiki/start/topics/examples/SSL-Offloader/
* https://www.cyberciti.biz/tips/linux-unix-bsd-nginx-webserver-security.html
* [Nginx Secure Web Server with HTTP, HTTPS SSL and Reverse Proxy Examples](https://calomel.org/nginx.html)
* https://github.com/nbs-system/naxsi/
* [nginx, TLS in database (Lua)](https://github.com/Vestorly/nginx-dynamic-ssl/blob/master/conf/nginx.conf)
* https://github.com/littlebizzy/slickstack/blob/master/nginx/nginx-conf.txt

### PHP

* https://github.com/php/php-src
* https://gist.github.com/nlehuen/2662513

* https://wiki.archlinux.org/index.php/PHP

### ArchLinux

* https://wiki.archlinux.org/index.php/Improving_performance
* https://wiki.archlinux.org/index.php/sysctl
