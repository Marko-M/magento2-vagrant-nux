#!/bin/bash

MAGENTO_TIMEZONE=$1
MAGENTO_LANGUAGE=$2
MAGENTO_CURRENCY=$3
MAGENTO_SAMPLE_DATA=$4
AUTH_NAME=$5
AUTH_PASS=$6
DOMAIN=$7

# Prints command traces
set -x

# Create required directories
mkdir -p ~/bin ~/.composer ~/public_html/var/composer_home/

# Install composer
php -r "readfile('https://getcomposer.org/installer');" > composer-setup.php
php -f composer-setup.php -- --install-dir=$HOME/bin --filename=composer
php -r "unlink('composer-setup.php');
"

# Setup composer authentication
if [[ ! -f "$HOME/.composer/auth.json" ]]
    then
    # -g => global => ~/.composer/auth.json
    ~/bin/composer config -g http-basic.repo.magento.com $AUTH_NAME $AUTH_PASS
fi

# Link global auth.json to framework composer home (required for sample data)
if [[ -f "$HOME/.composer/auth.json" && ! -L "$HOME/public_html/var/composer_home/auth.json" ]]
    then
    ln -s ~/.composer/auth.json ~/public_html/var/composer_home/auth.json
fi

cd ~/public_html/

# Install composer dependencies
~/bin/composer install

# Prepare sample data
if [[ ${MAGENTO_SAMPLE_DATA} == 'Y' ]]
    then
    php -f bin/magento sampledata:deploy
fi

# Install Magento
php -f bin/magento setup:install \
--base-url=http://${DOMAIN} --db-host=localhost --db-name=magento2 --db-user=magento2 --db-password=magento2 \
--admin-firstname=Magento2 --admin-lastname=Magento2 --admin-email=magento2@example.com --admin-user=magento2 \
--admin-password=magento2 --backend-frontname=admin --language=${MAGENTO_LANGUAGE} --currency=${MAGENTO_CURRENCY} \
--timezone=${MAGENTO_TIMEZONE} --use-rewrites=1 --use-secure-admin=1

# Install sample data
if [[ ${MAGENTO_SAMPLE_DATA} == 'Y' ]]
    then
    php -f bin/magento setup:upgrade
fi

php -f bin/magento setup:di:compile

# If bin/magento exists, run cron every minute
echo '* * * * * test -f /home/vagrant/public_html/bin/magento && php -f /home/vagrant/public_html/bin/magento cron:run' | crontab -