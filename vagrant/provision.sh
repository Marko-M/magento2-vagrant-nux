#!/bin/bash

DOMAIN=${1}
MYSQL_DBNAME=${2}
MYSQL_USER=${3}
MYSQL_PASSWORD=${4}
TIMEZONE=${5}
VARNISH=${6}

# Internal variables
PAGE_CACHE_CONFIG=''

# Prints command traces
set -x

# Locale
locale-gen --purge --no-archive
dpkg-reconfigure locales

# Set timezone
echo ${TIMEZONE} | sudo tee /etc/timezone && sudo dpkg-reconfigure --frontend noninteractive tzdata

# Add repositories

# Redis server repository
add-apt-repository ppa:chris-lea/redis-server

# PhpMyAdmin repository
# Broken on 12.05.2016. so disabled for now
#add-apt-repository -y ppa:nijel/phpmyadmin

# Nginx repository
add-apt-repository -y ppa:nginx/stable

# PHP 5.6 repository
add-apt-repository -y ppa:ondrej/php5-5.6

# Update package information
apt-get update

# Upgrade packages
apt-get dist-upgrade -y

# Install packages

# MySQL debconf selections
debconf-set-selections <<< 'mysql-server mysql-server/root_password password root'
debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password root'

# phpMyAdmin debconf selections
debconf-set-selections <<< 'phpmyadmin phpmyadmin/dbconfig-install boolean true'
debconf-set-selections <<< 'phpmyadmin phpmyadmin/app-password-confirm password root'
debconf-set-selections <<< 'phpmyadmin phpmyadmin/mysql/admin-pass password root'
debconf-set-selections <<< 'phpmyadmin phpmyadmin/mysql/app-pass password root'
debconf-set-selections <<< 'phpmyadmin phpmyadmin/reconfigure-webserver multiselect none'

# Packages
apt-get install -y htop nginx-full redis-server mysql-server-5.6 php5-cli php5-gd php5-curl \
php5-mcrypt php5-fpm php5-intl php5-xsl php5-mysqlnd php5-cli php5-redis php5-xdebug \
nfs-common phpmyadmin cachefilesd git build-essential libsqlite3-dev ruby1.9.1-dev

# Add Varnish repository and install if required
if [[ ${VARNISH} == 'Y' ]]; then
    PAGE_CACHE_CONFIG='-varnish'

    # Varnish repository
    wget -q https://repo.varnish-cache.org/GPG-key.txt -O- | apt-key add -
    add-apt-repository "deb https://repo.varnish-cache.org/ubuntu/ trusty varnish-3.0"

    # Install varnish
    apt-get install -y varnish

    # Varnish daemon opts
    cp /home/vagrant/public_html/vagrant/etc/default/varnish /etc/default/varnish

    # Varnish .vcl file
    cat /home/vagrant/public_html/vagrant/etc/varnish/vagrant.vcl \
        | sed -e "s|{{DOMAIN}}|$DOMAIN|g" > /etc/varnish/vagrant.vcl
fi

# Bind MySQL to all interfaces (to allow connecting from host)
cp /home/vagrant/public_html/vagrant/etc/mysql/conf.d/bind_all_interfaces.cnf /etc/mysql/conf.d/bind_all_interfaces.cnf

# Create MySQL user
mysql -P"3306" -h"localhost" -u"root" -p"root" -e "
CREATE USER \"$MYSQL_USER\"@\"%\" IDENTIFIED WITH mysql_native_password;
GRANT USAGE ON *.* TO \"$MYSQL_USER\"@\"%\" REQUIRE NONE WITH MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS 0;
SET PASSWORD FOR \"$MYSQL_USER\"@\"%\" = PASSWORD(\"$MYSQL_PASSWORD\");
CREATE DATABASE IF NOT EXISTS \`$MYSQL_DBNAME\`;
GRANT ALL PRIVILEGES ON \`$MYSQL_DBNAME\`.* TO \"$MYSQL_USER\"@\"%\";
GRANT ALL PRIVILEGES ON *.* TO \"root\"@\"%\" WITH GRANT OPTION;
"

# PHP development mode
cp /home/vagrant/public_html/vagrant/etc/php5/mods-available/development.ini /etc/php5/mods-available/development.ini

cat /home/vagrant/public_html/vagrant/etc/php5/mods-available/development.ini \
 | sed -e "s|{{TIMEZONE}}|$TIMEZONE|g" > /etc/php5/mods-available/development.ini

# Enable PHP modules
php5enmod development mcrypt

# PHP-FPM pool
cp /home/vagrant/public_html/vagrant/etc/php5/fpm/pool.d/vagrant.conf /etc/php5/fpm/pool.d/vagrant.conf

# Generate ssl certificate
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=$DOMAIN" \
-keyout /etc/ssl/private/vagrant.key -out /etc/ssl/certs/vagrant.crt &> /dev/null

# Generate dhparam
openssl dhparam -out /etc/ssl/private/vagrant-dhparam.pem 2048 &> /dev/null

# Make Nginx depend on Upstart vagrant-mounted event
cp /home/vagrant/public_html/vagrant/etc/init/nginx.conf /etc/init/nginx.conf

# Nginx snippets
cp /home/vagrant/public_html/vagrant/etc/nginx/snippets/vagrant-ssl.conf /etc/nginx/snippets/vagrant-ssl.conf
cp /home/vagrant/public_html/vagrant/etc/nginx/snippets/vagrant-main.conf /etc/nginx/snippets/vagrant-main.conf

# Nginx virtualhosts
rm /etc/nginx/sites-enabled/default

# Phpmyadmin
cat /home/vagrant/public_html/vagrant/etc/nginx/sites-available/phpmyadmin${PAGE_CACHE_CONFIG} \
 | sed -e "s|{{DOMAIN}}|$DOMAIN|g" > /etc/nginx/sites-available/phpmyadmin
ln -s /etc/nginx/sites-available/phpmyadmin /etc/nginx/sites-enabled/phpmyadmin

# Magento 2
cat /home/vagrant/public_html/vagrant/etc/nginx/sites-available/vagrant${PAGE_CACHE_CONFIG} \
 | sed -e "s|{{DOMAIN}}|$DOMAIN|g" > /etc/nginx/sites-available/vagrant
ln -s /etc/nginx/sites-available/vagrant /etc/nginx/sites-enabled/vagrant

# cachefilesd
echo "RUN=yes" >> /etc/default/cachefilesd

# Add www-data user to vagrant group (support restrictive document root permission schemes - yes, Magento 2, you!)
adduser www-data vagrant

# Install Mailcatcher
gem install mime-types --version "< 3" 2>/dev/null
gem install --conservative mailcatcher 2>/dev/null

# Adjust PHP for Mailcatcher
cp /home/vagrant/public_html/vagrant/etc/php5/mods-available/mailcatcher.ini /etc/php5/mods-available/mailcatcher.ini
php5enmod mailcatcher

# Upstart service
cp /home/vagrant/public_html/vagrant/etc/init/mailcatcher.conf /etc/init/mailcatcher.conf

# Start Mailcatcher
service mailcatcher start

# Restart services
service cachefilesd restart
service php5-fpm restart
service nginx restart
service varnish restart
service mysql restart
