#!/usr/bin/env bash

# Update Package List

apt-get update

# Force locale to avoid common localization pitfalls

echo "LC_ALL=en_US.UTF-8" >> /etc/default/locale
locale-gen en_US.UTF-8

# Install Some PPAs

apt-get install -y software-properties-common

apt-add-repository ppa:nginx/development -y
apt-add-repository ppa:rwky/redis -y
apt-add-repository ppa:chris-lea/node.js -y
apt-add-repository ppa:ondrej/php5-5.6 -y

# Add Repositories and Keys

## HHVM

wget -O - http://dl.hhvm.com/conf/hhvm.gpg.key | apt-key add -
echo deb http://dl.hhvm.com/ubuntu trusty main | tee /etc/apt/sources.list.d/hhvm.list

## MariaDB

apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xcbcb082a1bb943db
add-apt-repository 'deb http://mirrors.digitalocean.com/mariadb/repo/10.0/ubuntu trusty main'

## Blackfire
curl -s https://packagecloud.io/gpg.key | sudo apt-key add -
echo "deb http://packages.blackfire.io/debian any main" | sudo tee /etc/apt/sources.list.d/blackfire.list

# Update Package Lists

apt-get update

apt-get upgrade -y

# Install Some Basic Packages

apt-get install -y build-essential curl dos2unix gcc git libmcrypt4 libpcre3-dev \
make python2.7-dev python-pip re2c supervisor unattended-upgrades whois vim \
python-software-properties apache2-utils keychain imagemagick

# Install A Few Helpful Python Packages

pip install httpie
pip install fabric
pip install python-simple-hipchat

# Set My Timezone

ln -sf /usr/share/zoneinfo/UTC /etc/localtime

# Install PHP Stuffs

apt-get install -y php5-cli php5-dev php-pear \
php5-mysqlnd php5-pgsql php5-sqlite \
php5-apcu php5-json php5-curl php5-gd \
php5-gmp php5-imap php5-mcrypt php5-xdebug \
php5-memcached php5-redis

# Make MCrypt Available

ln -s /etc/php5/conf.d/mcrypt.ini /etc/php5/mods-available
sudo php5enmod mcrypt

# Install Mailparse PECL Extension

pecl install mailparse
echo "extension=mailparse.so" > /etc/php5/mods-available/mailparse.ini
ln -s /etc/php5/mods-available/mailparse.ini /etc/php5/cli/conf.d/20-mailparse.ini

# Install Composer

curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer

# Add Composer Global Bin To Path

printf "\nPATH=\"/home/vagrant/.composer/vendor/bin:\$PATH\"\n" | tee -a /home/vagrant/.profile

# Install Laravel Envoy

sudo su vagrant <<'EOF'
/usr/local/bin/composer global require "laravel/envoy=~1.0"
EOF

# Set Some PHP CLI Settings

sudo sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php5/cli/php.ini
sudo sed -i "s/display_errors = .*/display_errors = On/" /etc/php5/cli/php.ini
sudo sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/php5/cli/php.ini
sudo sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php5/cli/php.ini

# Install Nginx, PHP-FPM & HHVM

apt-get install -y nginx php5-fpm hhvm

# Configure Nginx

rm /etc/nginx/sites-enabled/default
rm /etc/nginx/sites-available/default
rm /etc/nginx/nginx.conf
rm /etc/nginx/fastcgi_params
mkdir /etc/nginx/includes/
cp /vagrant/configs/nginx/nginx.conf /etc/nginx/nginx.conf
cp /vagrant/configs/nginx/fastcgi_params /etc/nginx/fastcgi_params
cp /vagrant/configs/nginx/conf.d/gzip.conf /etc/nginx/conf.d/gzip.conf
cp /vagrant/configs/nginx/conf.d/ssl.conf /etc/nginx/conf.d/ssl.conf
cp /vagrant/configs/nginx/conf.d/restrictions.conf /etc/nginx/conf.d/restrictions.conf
cp /vagrant/configs/nginx/includes/common.conf /etc/nginx/includes/common.conf
cp /vagrant/configs/nginx/includes/restrictions.conf /etc/nginx/includes/restrictions.conf
cp /vagrant/configs/nginx/includes/php-fpm.conf /etc/nginx/includes/php-fpm.conf
cp /vagrant/configs/nginx/includes/hhvm.conf /etc/nginx/includes/hhvm.conf

# Configure HHVM To Run As Homestead

service hhvm stop
sed -i 's/#RUN_AS_USER="www-data"/RUN_AS_USER="vagrant"/' /etc/default/hhvm
service hhvm start

# Start HHVM On System Start

update-rc.d hhvm defaults

# Setup Some PHP-FPM Options

ln -s /etc/php5/mods-available/mailparse.ini /etc/php5/fpm/conf.d/20-mailparse.ini

sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php5/fpm/php.ini
sed -i "s/display_errors = .*/display_errors = On/" /etc/php5/fpm/php.ini
sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php5/fpm/php.ini
sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/php5/fpm/php.ini
sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php5/fpm/php.ini

echo "xdebug.remote_enable = 1" >> /etc/php5/fpm/conf.d/20-xdebug.ini
echo "xdebug.remote_connect_back = 1" >> /etc/php5/fpm/conf.d/20-xdebug.ini
echo "xdebug.remote_port = 9000" >> /etc/php5/fpm/conf.d/20-xdebug.ini
echo "xdebug.max_nesting_level = 1000" >> /etc/php5/fpm/conf.d/20-xdebug.ini

# Setup SSL for Nginx

if [[ ! -d /etc/nginx/ssl ]]; then
	mkdir /etc/nginx/ssl/
fi
if [[ ! -e /etc/nginx/ssl/dhparam.pem ]]; then
    openssl dhparam -out /etc/nginx/ssl/dhparam.pem 2048
fi
if [[ ! -e /etc/nginx/ssl/server.key ]]; then
	openssl genrsa -out /etc/nginx/ssl/server.key 2048 2>&1
fi
if [[ ! -e /etc/nginx/ssl/server.csr ]]; then
	openssl req -new -batch -key /etc/nginx/ssl/server.key -out /etc/nginx/ssl/server.csr
fi
if [[ ! -e /etc/nginx/ssl/server.crt ]]; then
	openssl x509 -req -days 365 -in /etc/nginx/ssl/server.csr -signkey /etc/nginx/ssl/server.key -out /etc/nginx/ssl/server.crt 2>&1
fi

# Set The Nginx & PHP-FPM User

sed -i "s/user = www-data/user = vagrant/" /etc/php5/fpm/pool.d/www.conf
sed -i "s/group = www-data/group = vagrant/" /etc/php5/fpm/pool.d/www.conf

sed -i "s/;listen\.owner.*/listen.owner = vagrant/" /etc/php5/fpm/pool.d/www.conf
sed -i "s/;listen\.group.*/listen.group = vagrant/" /etc/php5/fpm/pool.d/www.conf
sed -i "s/;listen\.mode.*/listen.mode = 0666/" /etc/php5/fpm/pool.d/www.conf

service nginx restart
service php5-fpm restart

# Add Vagrant User To WWW-Data

usermod -a -G www-data vagrant
id vagrant
groups vagrant

# Install Node

apt-get install -y nodejs
npm install -g grunt-cli
npm install -g gulp
npm install -g bower

# Install SQLite

apt-get install -y sqlite3 libsqlite3-dev

# Install MariaDB

debconf-set-selections <<< "mariadb-server mysql-server/root_password password secret"
debconf-set-selections <<< "mariadb-server mysql-server/root_password_again password secret"
apt-get install -y mariadb-server

# Replace deprecated key_buffer in my.cnf

sed -i '/^key_buffer[[:space:]]/s/key_buffer/key_buffer_size/' /etc/mysql/my.cnf
service mysql restart

# Configure MariaDB Remote Access

sed -i '/^bind-address/s/bind-address.*=.*/bind-address = 10.0.2.15/' /etc/mysql/my.cnf
mysql --user="root" --password="secret" -e "GRANT ALL ON *.* TO root@'10.0.2.2' IDENTIFIED BY 'secret' WITH GRANT OPTION;"
service mysql restart

mysql --user="root" --password="secret" -e "CREATE USER 'homestead'@'10.0.2.2' IDENTIFIED BY 'secret';"
mysql --user="root" --password="secret" -e "GRANT ALL ON *.* TO 'homestead'@'10.0.2.2' IDENTIFIED BY 'secret' WITH GRANT OPTION;"
mysql --user="root" --password="secret" -e "GRANT ALL ON *.* TO 'homestead'@'%' IDENTIFIED BY 'secret' WITH GRANT OPTION;"
mysql --user="root" --password="secret" -e "FLUSH PRIVILEGES;"
service mysql restart

# Install Postgres

apt-get install -y postgresql postgresql-contrib

# Configure Postgres Remote Access

sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /etc/postgresql/9.3/main/postgresql.conf
echo "host    all             all             10.0.2.2/32               md5" | tee -a /etc/postgresql/9.3/main/pg_hba.conf
sudo -u postgres psql -c "CREATE ROLE homestead LOGIN UNENCRYPTED PASSWORD 'secret' SUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION;"
service postgresql restart

# Install Blackfire
apt-get install -y blackfire-agent blackfire-php

# Install A Few Other Things

apt-get install -y redis-server memcached beanstalkd

# Configure Beanstalkd

sudo sed -i "s/#START=yes/START=yes/" /etc/default/beanstalkd
sudo /etc/init.d/beanstalkd start

# Enable swap memory

/bin/dd if=/dev/zero of=/var/swap.1 bs=1M count=1024
/sbin/mkswap /var/swap.1
/sbin/swapon /var/swap.1

# Enable SSH env variable forwarding for GIT_*

sed -i "s/AcceptEnv LANG LC_*/AcceptEnv LANG LC_* GIT_*/" /etc/ssh/sshd_config

# Write Bash Aliases

cp /vagrant/aliases /home/vagrant/.bash_aliases
