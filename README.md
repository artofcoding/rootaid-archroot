# archroot

This document describes setup of ArchLinux virtual server with database, web server Nginx, Lets Encrypt and PHP (F)astCGI (P)rocess (M)anager.

## TODO

https://haydenjames.io/php-fpm-tuning-using-pm-static-max-performance/

disable_functions = apache_child_terminate, apache_get_modules, apache_get_version, apache_getenv, apache_note, apache_setenv, disk_free_space, diskfreespace, dl, escapeshellcmd, exec, ini_alter, ini_get_all, ini_restore, ini_set, passthru, php_uname, phpinfo, popen, proc_nice, proc_open, shell_exec, show_source, symlink, system

MySQL Socket, auch php.ini mysqli.default_socket =

PHP extensions
curl
exif
gd
iconv
imap
ldap
mysqli
zend_extension=opcache
pdo_mysql
zip

## tl;dr

To setup everything:

* Docker, Portainer
* MariaDB
* nginx
* PHP

get a vanilla ArchLinux system and:

    pacman --noconfirm -Syu
    pacman --noconfirm -S git
    git clone https://github.com/artofcoding/rootaid-archroot.git
    sudo cp rootaid-archroot/*.sh /usr/local/bin
    sudo chmod 755 /usr/local/bin/*.sh
    sudo archroot.sh install
    # Maybe setup storage, see below
    sudo archroot.sh setup-srvhttp
    sudo archroot-mariadb.sh install
    sudo archroot-nginx.sh install
    sudo archroot-nginx.sh configure
    sudo archroot-php-fpm.sh install
    sudo archroot-php-fpm.sh configure
    sudo archroot-docker.sh install
    sudo archroot-docker.sh install-portainer
    sudo archroot-docker.sh install-php

## Setup

Install git:

    pacman --noconfirm -S git

Clone repository:

    cd ~
    git clone https://github.com/artofcoding/rootaid-archroot.git

Initially copy scripts:

    sudo cp rootaid-archroot/*.sh /usr/local/bin
    sudo chmod 755 /usr/local/bin/*.sh

Update regularly:

    ( crontab -l ; echo "0 * * * * ( cd ~/rootaid-archroot ; git reset --hard ; git pull ; sudo cp *.sh /usr/local/bin)" ) | crontab -

## Preface

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

* [Nginx Wiki](https://www.nginx.com/resources/wiki/start/)
* [Nginx Wiki, SSL-Offloader](https://www.nginx.com/resources/wiki/start/topics/examples/SSL-Offloader/)
* [Cyberciti, Webserver Security](https://www.cyberciti.biz/tips/linux-unix-bsd-nginx-webserver-security.html)
* [Nginx Secure Web Server with HTTP, HTTPS SSL and Reverse Proxy Examples](https://calomel.org/nginx.html)
* [Naxsi](https://github.com/nbs-system/naxsi/)
* [nginx, TLS in database (Lua)](https://github.com/Vestorly/nginx-dynamic-ssl/blob/master/conf/nginx.conf)
* [Slickstack, nginx-conf](https://github.com/littlebizzy/slickstack/blob/master/nginx/nginx-conf.txt)

### PHP

* https://github.com/php/php-src
* https://gist.github.com/nlehuen/2662513

* https://wiki.archlinux.org/index.php/PHP

* https://downloads.joomla.org/de/technical-requirements-de

### ArchLinux

* [ArchLinux Wiki: Improving performance](https://wiki.archlinux.org/index.php/Improving_performance)
* [ArchLinux Wiki: sysctl](https://wiki.archlinux.org/index.php/sysctl)
* [ArchLinux Wiki: Chroot (Arch reparieren)](https://wiki.archlinux.de/title/Chroot_(Arch_reparieren))
* [ArchLinux Wiki: General troubleshooting](https://wiki.archlinux.org/index.php/General_troubleshooting)
* [ArchLinux Wiki: mkinitcpio](https://wiki.archlinux.org/index.php/Mkinitcpio)
