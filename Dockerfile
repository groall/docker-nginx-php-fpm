FROM ubuntu:14.04

MAINTAINER      groall <groall@nodasoft.com>

# Surpress Upstart errors/warning
RUN dpkg-divert --local --rename --add /sbin/initctl
RUN ln -sf /bin/true /sbin/initctl

# Let the conatiner know that there is no tty
ENV DEBIAN_FRONTEND noninteractive

# Set locale
RUN     locale-gen ru_RU.UTF-8 && locale-gen en_US.UTF-8 && dpkg-reconfigure locales

# Set time
RUN     mv /etc/localtime /etc/localtime-old && \
        ln -s /usr/share/zoneinfo/Europe/Moscow /etc/localtime

ENV     PHP5_DATE_TIMEZONE Europe/Moscow

# Update base image
# Add sources for latest nginx
# Install software requirements
RUN     apt-get update && \
        apt-get install -y software-properties-common && \
        nginx=stable && \
        add-apt-repository ppa:nginx/$nginx && \
        apt-get update && \
        apt-get upgrade -y && \
        BUILD_PACKAGES="php5-fpm php5-mysql php-apc php5-curl php5-gd php5-intl php5-mcrypt php5-memcached \
        php5-xmlrpc php-pear php5-dev php-http php5-cli php5-imap php5-xdebug php5-imagick \
        nginx \
        gcc make g++ build-essential tcl wget git tzdata curl zip nano ca-certificates inotify-tools pwgen supervisor \
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

# Enable mcrypt
#RUN     php5enmod mcrypt

# Install pecl modules
RUN     yes | pecl install redis amqp  apcu-4.0.7 xhprof-0.9.4 raphf propro  pecl_http-1.7.6 protobuf-3.1.0a1 grpc

# Tweak nginx config
RUN     sed -i -e"s/worker_processes  1/worker_processes 5/" /etc/nginx/nginx.conf && \
        sed -i -e"s/keepalive_timeout\s*65/keepalive_timeout 2/" /etc/nginx/nginx.conf && \
        sed -i -e"s/keepalive_timeout 2/keepalive_timeout 2;\n\tclient_max_body_size 100m/" /etc/nginx/nginx.conf
RUN     echo "daemon off;" >> /etc/nginx/nginx.conf

# Remove nginx site conf
RUN     rm -Rf /etc/nginx/conf.d/* && \
        rm -Rf /etc/nginx/sites-available/default

# Tweak php-fpm config
# Remove pool's configs
RUN     sed -i -e"s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 100M/g" /etc/php5/fpm/php.ini && \
        sed -i -e"s/post_max_size\s*=\s*8M/post_max_size = 100M/g" /etc/php5/fpm/php.ini && \
        sed -i -e"s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" /etc/php5/fpm/php.ini && \
        sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php5/fpm/php-fpm.conf && \
        echo "xdebug.remote_port=9002" >> /etc/php5/fpm/conf.d/25-modules.ini && \
        echo "xdebug.remote_enable=1" >> /etc/php5/fpm/conf.d/25-modules.ini && \
        echo "xdebug.remote_handler=dbgp" >> /etc/php5/fpm/conf.d/25-modules.ini && \
        echo "xdebug.remote_host=172.17.42.1" >> /etc/php5/fpm/conf.d/25-modules.ini && \
        echo "xdebug.idekey=PHPSTORM" >> /etc/php5/fpm/conf.d/25-modules.ini && \
        echo "xdebug.max_nesting_level=1000" >> /etc/php5/fpm/conf.d/25-modules.ini && \
        echo "xdebug.remote_autostart=1" >> /etc/php5/fpm/conf.d/25-modules.ini && \
        echo "extension=redis.so" >> /etc/php5/fpm/conf.d/25-modules.ini && \
        echo "extension=amqp.so" >> /etc/php5/fpm/conf.d/25-modules.ini && \
        echo "extension=xhprof.so" >> /etc/php5/fpm/conf.d/25-modules.ini && \
        echo "extension=raphf.so" >> /etc/php5/fpm/conf.d/25-modules.ini && \
        echo "extension=propro.so" >> /etc/php5/fpm/conf.d/25-modules.ini && \
        echo "extension=http.so" >> /etc/php5/fpm/conf.d/25-modules.ini && \
        echo "extension=protobuf.so" >> /etc/php5/fpm/conf.d/25-modules.ini && \
        echo "extension=grpc.so" >> /etc/php5/fpm/conf.d/25-modules.ini && \
        rm -Rf /etc/php5/fpm/pool.d/* && \
        find /etc/php5/cli/conf.d/ -name "*.ini" -exec sed -i -re 's/^(\s*)#(.*)/\1;\2/g' {} \;

# Supervisor Config
ADD ./supervisord.conf /etc/supervisord.conf

# Start Supervisord
ADD ./start.sh /start.sh
RUN chmod 755 /start.sh

# nginx site conf
#ADD ./nginx-site.conf /etc/nginx/sites-available/default.conf
#RUN ln -s /etc/nginx/sites-available/default.conf /etc/nginx/sites-enabled/default.conf

#RUN chown -Rf www-data.www-data /usr/share/nginx/html/

#CMD ["/bin/bash", "/start.sh"]