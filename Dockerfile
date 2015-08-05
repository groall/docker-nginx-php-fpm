FROM ubuntu:14.04

MAINTAINER      groall <groall@nodasoft.com>


# locale
RUN     locale-gen ru_RU.UTF-8 && locale-gen en_US.UTF-8 && dpkg-reconfigure locales

# time
RUN     mv /etc/localtime /etc/localtime-old && \
        ln -s /usr/share/zoneinfo/Europe/Moscow /etc/localtime

ENV     PHP5_DATE_TIMEZONE Europe/Moscow

# update
RUN     apt-get update && \
        apt-get install -y software-properties-common && \
        nginx=development && \
        add-apt-repository ppa:nginx/$nginx && \
        apt-get update && \
        apt-get upgrade -y

# install packages
RUN     BUILD_PACKAGES="php5-fpm php5-mysql php-apc php5-curl php5-gd php5-intl php5-mcrypt php5-memcached \
        php5-xmlrpc php-pear php5-dev php-http php5-cli php5-imap php5-xdebug php5-imagick \
        nginx \
        gcc make g++ build-essential tcl wget git tzdata curl zip nano \
        libpcre3-dev libevent-dev libmagic-dev librabbitmq1 librabbitmq-dev libcurl3 libcurl4-openssl-dev libssh2-php libc6-dev" && \
        apt-get install -y $BUILD_PACKAGES && \
        apt-get remove --purge -y software-properties-common && \
        apt-get autoremove -y && \
        apt-get clean && \
        apt-get autoclean && \
        echo -n > /var/lib/apt/extended_states && \
        rm -rf /var/lib/apt/lists/* && \
        rm -rf /usr/share/man/?? && \
        rm -rf /usr/share/man/??_*

# enable mcrypt
#RUN     php5enmod mcrypt

# install pecl modules
RUN     yes | pecl install redis amqp  apcu-4.0.7 xhprof-0.9.4 raphf propro  pecl_http-1.7.6

# tweak nginx config
RUN     sed -i -e"s/worker_processes  1/worker_processes 5/" /etc/nginx/nginx.conf && \
        sed -i -e"s/keepalive_timeout\s*65/keepalive_timeout 2/" /etc/nginx/nginx.conf && \
        sed -i -e"s/keepalive_timeout 2/keepalive_timeout 2;\n\tclient_max_body_size 100m/" /etc/nginx/nginx.conf && \

# tweak php-fpm config
RUN     sed -i -e "s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 100M/g" /etc/php5/fpm/php.ini && \
        sed -i -e "s/post_max_size\s*=\s*8M/post_max_size = 100M/g" /etc/php5/fpm/php.ini && \
        sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" /etc/php5/fpm/pool.d/www.conf && \
        sed -i -e "s/pm.max_children = 5/pm.max_children = 10/g" /etc/php5/fpm/pool.d/www.conf && \
        sed -i -e "s/pm.start_servers = 2/pm.start_servers = 3/g" /etc/php5/fpm/pool.d/www.conf && \
        sed -i -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 2/g" /etc/php5/fpm/pool.d/www.conf && \
        sed -i -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 4/g" /etc/php5/fpm/pool.d/www.conf && \
        sed -i -e "s/pm.max_requests = 500/pm.max_requests = 1000/g" /etc/php5/fpm/pool.d/www.conf && \
        sed -i -e "s/error_reporting = E_ALL & ~E_NOTICE/error_reporting = E_ALL & ~E_DEPRECATED & ~E_NOTICE & ~E_STRICT/g" /etc/php5/fpm/pool.d/www.conf && \
        echo "xdebug.remote_port=9002" >> /etc/php5/fpm/conf.d/25-modules.ini && \
        echo "xdebug.remote_enable=1 >> /etc/php5/fpm/conf.d/25-modules.ini && \
        echo "xdebug.remote_handler=dbgp >> /etc/php5/fpm/conf.d/25-modules.ini && \
        echo "xdebug.remote_host=172.17.42.1 >> /etc/php5/fpm/conf.d/25-modules.ini && \
        echo "xdebug.idekey=PHPSTORM >> /etc/php5/fpm/conf.d/25-modules.ini && \
        echo "xdebug.max_nesting_level=1000 >> /etc/php5/fpm/conf.d/25-modules.ini && \
        echo "xdebug.remote_autostart=1 >> /etc/php5/fpm/conf.d/25-modules.ini && \
        echo "extension=redis.so >> /etc/php5/fpm/conf.d/25-modules.ini && \
        echo "extension=amqp.so >> /etc/php5/fpm/conf.d/25-modules.ini && \
        echo "extension=xhprof.so >> /etc/php5/fpm/conf.d/25-modules.ini && \
        echo "extension=raphf.so >> /etc/php5/fpm/conf.d/25-modules.ini && \
        echo "extension=propro.so >> /etc/php5/fpm/conf.d/25-modules.ini && \
        echo "extension=http.so >> /etc/php5/fpm/conf.d/25-modules.ini

# fix ownership of sock file for php-fpm
RUN     sed -i -e "s/;listen.mode = 0660/listen.mode = 0750/g" /etc/php5/fpm/pool.d/www.conf && \
        find /etc/php5/cli/conf.d/ -name "*.ini" -exec sed -i -re 's/^(\s*)#(.*)/\1;\2/g' {} \;

# nginx site conf
RUN     rm -Rf /etc/nginx/conf.d/* && \
        rm -Rf /etc/nginx/sites-available/default && \

# Supervisor Config
RUN /usr/bin/easy_install supervisor
RUN /usr/bin/easy_install supervisor-stdout
ADD ./supervisord.conf /etc/supervisord.conf

ADD ./start.sh /start.sh
RUN chmod 755 /start.sh

CMD ["/bin/bash", "/start.sh"]