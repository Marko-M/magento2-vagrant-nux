# Magento 2 Vagrant for Unix based hosts

This Vagrant environment was crafted to run best on Linux hosts. Due to mounting shares through NFSv4 to improve performance, Windows is not supported. Mac OS X hasn't been tested.

## Guest

 * Ubuntu 14.04 LTS 64-bit
 * NFSv4 with FS-Cache
 * Nginx 1.8
 * PHP-FPM 5.6
 * MySQL 5.6
 * Redis 3.0
 * phpMyAdmin
 * Fake /usr/sbin/sendmail (logs emails to $HOME/mail)
 * 2 cores, 2048 MB of RAM
 
## Host
 
### NFS server

In order to provide performance document root sharing between host and guest, NFS server with FS-Cache is used.

#### Ubuntu

To install on recent Ubuntu distributions:

```sh
sudo apt-get install nfs-kernel-server
```

Last several Ubuntu versions encounter difficulties with group permissions, combined with Magento 2 permissions scheme, this creates difficulties when loading static resources. It's required to disable `--manage-gids` on `rpc.mountd`:

```sh
sudo sed -i -e 's|--manage-gids||g' /etc/default/nfs-kernel-server
sudo service nfs-kernel-server restart
```

### /etc/hosts

If you adjusted domain using `Vagrantfile.local`, you should adjust following line as well:

```sh
echo "192.168.56.6 magento2.loc phpmyadmin.magento2.loc" | sudo tee -a /etc/hosts
```

### Configuration

This Vagrant environment can be adjusted by copying `Vagrantfile.local.sample` to `Vagrantfile.local`, and making adjustments there. Here's what's adjustable:

```ruby
# -*- mode: ruby -*-
# vi: set ft=ruby :
# Copy to Vagrantfile.local and modify

# Add "192.168.56.6 $DOMAIN phpmyadmin.$DOMAIN" to your host /etc/hosts
DOMAIN = 'localhost.loc'

# MySQL
# Due to MySQL limitations, up to 16 characters here, more will get truncated
MYSQL_DBNAME = 'magento2'
MYSQL_USER = 'magento2'
MYSQL_PASSWORD = 'magento2'

# PHP
PHP_TIMEZONE = 'America/Los_Angeles'

# Magento
MAGENTO_INSTALL = 'Y'
MAGENTO_TIMEZONE = 'America/Los_Angeles'
MAGENTO_LANGUAGE = 'en_US'
MAGENTO_CURRENCY = 'USD'
MAGENTO_SAMPLE_DATA = 'Y'

# Composer auth (required if MAGENTO_INSTALL == 'Y')
AUTH_NAME = ''
AUTH_PASSWORD = ''
```
By default both Magento 2 (`MAGENTO_INSTALL`) and Magento 2 sample data (MAGENTO_SAMPLE_DATA) will be installed. Make sure you provide `AUTH_NAME` and `AUTH_PASSWORD` if want Magento 2 installed, because it's required for authentication with Magento composer repository access.

## PHP

Relevant php.ini directives:

```
; General
max_input_time = 600
max_execution_time = 600
max_input_vars = 5000
memory_limit = 1024M
error_reporting = E_ALL
display_errors = On
display_startup_errors = On
upload_max_filesize = 32M
post_max_size = 32M
session.gc_maxlifetime = 14400
date.timezone = {{PHP_TIMEZONE}}

; Xdebug
xdebug.remote_enable = on
xdebug.remote_handler= dbgp
xdebug.remote_host= localhost
xdebug.remote_port = 9000

xdebug.profiler_enable=0
xdebug.profiler_output_dir=/tmp
xdebug.profiler_enable_trigger=1
xdebug.max_nesting_level = 1000

; Xdebug Vagrant specific
xdebug.remote_connect_back = on
```

## MySQL

* Root user: `root`
* Root password: `root`
* Magento database: `magento2`
* Magento user: `magento2`
* Magento password: `magento2`

## Magento

* Magento Frontend: `http://magento2.loc`
* Magento Admin: `http://magento2.loc/admin`
* phpMyAdmin: `http://phpmyadmin.magento2.loc`
* Admin user: `magento2`
* Admin password: `magento2`

MAGE_MODE is set to developer.

