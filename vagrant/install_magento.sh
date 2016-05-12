#!/bin/bash

TIMEZONE=${1}
MAGENTO_LANGUAGE=${2}
MAGENTO_CURRENCY=${3}
MAGENTO_SAMPLE_DATA=${4}
AUTH_NAME=${5}
AUTH_PASS=${6}
DOMAIN=${7}
VARNISH=${8}
MYSQL_DBNAME=${9}
MYSQL_USER=${10}
MYSQL_PASSWORD=${11}

# Prints command traces
set -x

cd ~/public_html/

# Purge document root from previous installation
rm -fr var/* vendor/* app/etc/config.php app/etc/env.php

# Make sure required directories are in place
mkdir -p ~/bin ~/.composer ~/public_html/var/composer_home/

# Install composer if required
php -r "readfile('https://getcomposer.org/installer');" > composer-setup.php
php -f composer-setup.php -- --install-dir=$HOME/bin --filename=composer
php -r "unlink('composer-setup.php');"

# Setup global auth.json
~/bin/composer config -g http-basic.repo.magento.com $AUTH_NAME $AUTH_PASS

# Link global auth.json to framework composer home (required for sample data)
if [[ -f "$HOME/.composer/auth.json" ]]; then
    ln -s ~/.composer/auth.json ~/public_html/var/composer_home/auth.json
fi

# Install composer dependencies
~/bin/composer install

# Handle sample data
if [[ ${MAGENTO_SAMPLE_DATA} == 'Y' ]]; then
    php -f bin/magento sampledata:deploy
else
    php -f bin/magento sampledata:remove
fi

# Install Magento
php -f bin/magento setup:install \
--base-url=http://${DOMAIN} --base-url-secure=https://${DOMAIN} --db-host=localhost --db-name=${MYSQL_DBNAME} --db-user=${MYSQL_USER} --db-password=${MYSQL_PASSWORD} \
--admin-firstname=Magento2 --admin-lastname=Magento2 --admin-email=magento2@example.com --admin-user=magento2 \
--admin-password=magento2 --backend-frontname=admin --language=${MAGENTO_LANGUAGE} --currency=${MAGENTO_CURRENCY} \
--timezone=${TIMEZONE} --use-rewrites=1 --use-secure-admin=1 --use-secure=1 --http-cache-hosts=localhost

# Adjust Magento caching application
if [[ ${VARNISH} == 'Y' ]]; then
    mysql -P"3306" -h"localhost" -u"${MYSQL_USER}" -p"${MYSQL_USER}" -e "
INSERT INTO \`magento2\`.\`core_config_data\` (\`scope\`, \`scope_id\`, \`path\`, \`value\`)
    VALUES (\"default\", \"0\", \"system/full_page_cache/caching_application\", \"2\");
"
fi

# Install sample data
if [[ ${MAGENTO_SAMPLE_DATA} == 'Y' ]]; then
    php -f bin/magento setup:upgrade
fi

# Compile DI
php -f bin/magento setup:di:compile

# Flush cache
php -f bin/magento cache:flush

# Run cron every minute
echo '* * * * * test -f $HOME/public_html/bin/magento && php -f $HOME/public_html/bin/magento cron:run' | crontab -
