#!/bin/bash

DOMAIN=$1
MYSQL_DBNAME=$2
MYSQL_USER=$3
MYSQL_PASSWORD=$4
TIMEZONE=$5

# Prints command traces
set -x

# Locale
export LANGUAGE=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_TYPE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
locale-gen en_US en_US.UTF-8
dpkg-reconfigure locales

# Set timezone
echo ${TIMEZONE} | sudo tee /etc/timezone && sudo dpkg-reconfigure --frontend noninteractive tzdata

# Add repositories

# Redis server repository
add-apt-repository ppa:chris-lea/redis-server

# PhpMyAdmin repository
add-apt-repository -y ppa:nijel/phpmyadmin

# Nginx repository
add-apt-repository -y ppa:nginx/stable

# PHP 5.5 repository
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
nfs-common phpmyadmin cachefilesd

# Bind MySQL to all interfaces (to allow connecting from host)
cp /home/vagrant/public_html/vagrant/snippets/etc/mysql/conf.d/bind_all_interfaces.cnf /etc/mysql/conf.d/bind_all_interfaces.cnf

# Create MySQL user and add procedure for truncating database
mysql -P"3306" -h"localhost" -u"root" -p"root" -e "
CREATE USER \"$MYSQL_USER\"@\"%\" IDENTIFIED WITH mysql_native_password;
GRANT USAGE ON *.* TO \"$MYSQL_USER\"@\"%\" REQUIRE NONE WITH MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS 0;
SET PASSWORD FOR \"$MYSQL_USER\"@\"%\" = PASSWORD(\"$MYSQL_PASSWORD\");
CREATE DATABASE IF NOT EXISTS \`$MYSQL_DBNAME\`;
GRANT ALL PRIVILEGES ON \`$MYSQL_DBNAME\`.* TO \"$MYSQL_USER\"@\"%\";
GRANT ALL PRIVILEGES ON *.* TO \"root\"@\"%\" WITH GRANT OPTION;

USE \`$MYSQL_DBNAME\`;
DELIMITER //
CREATE PROCEDURE dropAllTables()
BEGIN
-- Temporary variable for the table name
DECLARE tableName NVARCHAR(255);
-- Wheteher or not the cursor is finished looping over the table list
DECLARE done INT DEFAULT FALSE;
-- A cursor over the table list read from the MySQL information schema database
DECLARE tableCursor CURSOR FOR SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA = (SELECT DATABASE());
-- Set up the error handler for breaking out of the loop reading the cursor
DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
-- Disable foreign key checks
SET FOREIGN_KEY_CHECKS = 0;
-- Open  the cursor
OPEN tableCursor;
-- Start looping over the records in the cursor
read_loop: LOOP
-- Read the next item into our tableName variable
FETCH tableCursor INTO tableName;
-- If fecth failed (and the error handler set done), exit the loop
IF done THEN
  LEAVE read_loop;
END IF;
-- Create the truncate query
SET @s = CONCAT(\"DROP TABLE \", tableName);
-- Prepare, execute and deallocate the truncate query
PREPARE dropStmt FROM @s;
EXECUTE dropStmt;
DEALLOCATE PREPARE dropStmt;
-- On to the next!
END LOOP;
-- Close the cursor, all should be cleaned up now
CLOSE tableCursor;
-- Enable foreign key checks
SET FOREIGN_KEY_CHECKS = 1;
END//
DELIMITER ;
"
# PHP development mode
cp /home/vagrant/public_html/vagrant/snippets/etc/php5/mods-available/development.ini /etc/php5/mods-available/development.ini

cat /home/vagrant/public_html/vagrant/snippets/etc/php5/mods-available/development.ini \
 | sed -e "s|{{TIMEZONE}}|$TIMEZONE|g" > /etc/php5/mods-available/development.ini

# Enable PHP modules
php5enmod development mcrypt

# PHP-FPM pool
cp /home/vagrant/public_html/vagrant/snippets/etc/php5/fpm/pool.d/vagrant.conf /etc/php5/fpm/pool.d/vagrant.conf

# Generate ssl certificate
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=$DOMAIN" \
-keyout /etc/ssl/private/vagrant.key -out /etc/ssl/certs/vagrant.crt &> /dev/null

# Generate dhparam
openssl dhparam -out /etc/ssl/private/vagrant-dhparam.pem 2048 &> /dev/null

# Nginx snippets
cp /home/vagrant/public_html/vagrant/snippets/etc/nginx/snippets/vagrant-ssl.inc /etc/nginx/snippets/vagrant-ssl.inc

# Nginx virtualhosts
rm /etc/nginx/sites-enabled/default

# Phpmyadmin
cat /home/vagrant/public_html/vagrant/snippets/etc/nginx/sites-available/phpmyadmin \
 | sed -e "s|{{DOMAIN}}|$DOMAIN|g" > /etc/nginx/sites-available/phpmyadmin
ln -s /etc/nginx/sites-available/phpmyadmin /etc/nginx/sites-enabled/phpmyadmin

# Magento 2
cat /home/vagrant/public_html/vagrant/snippets/etc/nginx/sites-available/vagrant \
 | sed -e "s|{{DOMAIN}}|$DOMAIN|g" > /etc/nginx/sites-available/vagrant
ln -s /etc/nginx/sites-available/vagrant /etc/nginx/sites-enabled/vagrant

# Sendmail
cp /home/vagrant/public_html/vagrant/snippets/usr/sbin/sendmail /usr/sbin/sendmail && chmod +x /usr/sbin/sendmail

# cachefilesd
echo "RUN=yes" >> /etc/default/cachefilesd

# Add www-data user to vagrant group (support restrictive document root permission schemes - yes, Magento 2, you!)
adduser www-data vagrant

# Make Nginx depend on Upstart vagrant-mounted event
sed -i -e "s|^\(start on.*\)|#\1\nstart on vagrant-mounted|g" /etc/init/nginx.conf

# Restart services
service cachefilesd restart
service php5-fpm restart
service nginx restart
service mysql restart
