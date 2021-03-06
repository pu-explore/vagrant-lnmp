#!/usr/bin/env bash

declare -A params=$5       # Create an associative array
declare -A headers=${6}    # Create an associative array
declare -A rewrites=${7}  # Create an associative array

paramsTXT=""
if [ -n "$5" ]; then
   for element in "${!params[@]}"
   do
      paramsTXT="${paramsTXT}
      fastcgi_param ${element} ${params[$element]};"
   done
fi

headersTXT=""
if [ -n "${6}" ]; then
   for element in "${!headers[@]}"
   do
      headersTXT="${headersTXT}
      add_header ${element} ${headers[$element]};"
   done
fi

rewritesTXT=""
if [ -n "${7}" ]; then
   for element in "${!rewrites[@]}"
   do
      rewritesTXT="${rewritesTXT}
      location ~ ${element} { if (!-f \$request_filename) { return 301 ${rewrites[$element]}; } }"
   done
fi

listen_80="${3:-80}"
listen_443="${4:-443} ssl http2"
server_name=".$1"
if [[ "${8}" != "false" ]]; then
    listen_80="80 default_server"
    listen_443="[::]:80 default_server"
    server_name="_"
fi

block="server {
    listen $listen_80;
    listen $listen_443;
    server_name $server_name;
    root $2;

    index index.html index.htm index.php;

    charset utf-8;
    client_max_body_size 100m;

    $rewritesTXT

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
        $headersTXT
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    access_log off;
    error_log  /var/log/nginx/$1-error.log error;

    sendfile off;

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        $paramsTXT

        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
    }

    location ~ /\.ht {
        deny all;
    }

    ssl_certificate     /etc/ssl/certs/$1.crt;
    ssl_certificate_key /etc/ssl/certs/$1.key;
}
"

echo "$block" > "/etc/nginx/sites-available/$1"
ln -fs "/etc/nginx/sites-available/$1" "/etc/nginx/sites-enabled/$1"
