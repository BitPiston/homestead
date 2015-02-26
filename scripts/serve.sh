#!/usr/bin/env bash

block="server {
    listen 80;
    listen [::]:80;
    listen 443 ssl spdy;
    listen [::]:443 ssl spdy;

    server_name $1 $2;
    root \"$3\";

    access_log off;
    error_log /var/log/nginx/$1-error.log error;

    include includes/restrictions.conf;
    include includes/common.conf;

    location / {
        try_files \$uri \$uri/ /index.php\$is_args\$args;
    }

    include includes/$4.conf;
}
"

echo "$block" > "/etc/nginx/sites-available/$1"
ln -fs "/etc/nginx/sites-available/$1" "/etc/nginx/sites-enabled/$1"
service nginx restart
service php5-fpm restart
