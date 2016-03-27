FROM debian:jessie
MAINTAINER Henrik Farre <henrik@rockhopper.dk>

ENV DEBIAN_FRONTEND=noninteractive \
DEBIAN_PRIORITY=critical \
DEBCONF_NOWARNINGS=yes \
MYSQL_PASS=mysql_root_password \
WEBGRIND_VERSION=1.2 \
MAILHOG_VERSION=0.2.0 \
XDEBUG_HOST=172.17.0.1 \
XDEBUG_PORT=9000

# Check local docker0 interface if Vdebug can't connect: ip addr show docker0

# Default config
RUN echo 'tzdata tzdata/Areas select Europe' | debconf-set-selections \
 && echo 'tzdata tzdata/Zones/Europe select Copenhagen' | debconf-set-selections \
 && echo 'mysql-server mysql-server/root_password password ${MYSQL_PASS}' | debconf-set-selections \
 && echo 'mysql-server mysql-server/root_password_again password ${MYSQL_PASS}' | debconf-set-selections \
 && echo 'phpmyadmin phpmyadmin/app-password-confirm password' | debconf-set-selections \
 && echo 'phpmyadmin phpmyadmin/dbconfig-install boolean true' | debconf-set-selections \
 && echo 'phpmyadmin phpmyadmin/mysql/admin-pass password ${MYSQL_PASS}' | debconf-set-selections \
 && echo 'phpmyadmin phpmyadmin/mysql/app-pass password ${MYSQL_PASS}' | debconf-set-selections \
 && echo 'phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2' | debconf-set-selections \
 && echo 'locales locales/locales_to_be_generated multiselect     en_US.UTF-8 UTF-8, en_GB.UTF-8 UTF-8, da_DK.UTF-8 UTF-8' | debconf-set-selections \
 && echo 'locales locales/default_environment_locale      select  da_DK.UTF-8' | debconf-set-selections

# Update and install
# Python and graphviz for webgrind
# ca-certificates else curl will fail on https
RUN apt-get -q -y update && apt-get -q -y --no-install-recommends upgrade \
 && apt-get -q -y --no-install-recommends install \
      ca-certificates \
      ssmtp \
      locales \
      apache2 \
      mariadb-server-10.0 \
      phpmyadmin \
      libapache2-mod-php5 \
      php-apc \
      php5-tidy \
      php5-curl \
      php-pear \
      php5-xdebug \
      curl \
      php5-mcrypt \
      php5-sqlite \
      imagemagick \
      php5-sybase \
      php5-ldap \
      python \
      graphviz \
 && apt-get clean \
 && rm -rf /var/lib/{apt,dpkg,cache,log}/ /tmp/* /var/tmp/* /var/cache/debconf/* \
 && rm -rf /usr/share/man/?? /usr/share/man/??_*

# Apache
RUN echo "ServerName jessie.localdomain" | tee /etc/apache2/conf-enabled/fqdn.conf \
  && a2enmod rewrite \
  && a2enmod php5 \
  && a2enmod headers \
  && a2enmod expires

# Composer and Drush
# http://docs.drush.org/en/master/install/
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin/ --filename=composer \
 && curl -O http://files.drush.org/drush.phar \
 && php drush.phar core-status \
 && chmod +x drush.phar \
 && mv drush.phar /usr/bin/drush

# PHP and Xdebug settings
RUN sed -i -e 's/post_max_size = 8M/post_max_size = 200M/' /etc/php5/apache2/php.ini \
    && sed -i -e 's/upload_max_filesize = 2M/upload_max_filesize = 200M/' /etc/php5/apache2/php.ini \
    && sed -i -e 's/;date.timezone =/date.timezone = Europe\/Copenhagen/' /etc/php5/apache2/php.ini \
    && echo xdebug.remote_enable=1 >> /etc/php5/apache2/conf.d/20-xdebug.ini;\
    echo xdebug.remote_autostart=1 >> /etc/php5/apache2/conf.d/20-xdebug.ini;\
    echo xdebug.remote_host=${XDEBUG_HOST} >> /etc/php5/apache2/conf.d/20-xdebug.ini;\
    echo xdebug.remote_port=${XDEBUG_PORT} >> /etc/php5/apache2/conf.d/20-xdebug.ini;\
    echo xdebug.remote_log=/tmp/php5-xdebug.log >> /etc/php5/apache2/conf.d/20-xdebug.ini;\
    echo xdebug.profiler_enable=0 >> /etc/php5/apache2/conf.d/20-xdebug.ini;\
    echo xdebug.profiler_enable_trigger=1 >> /etc/php5/apache2/conf.d/20-xdebug.ini;\
    echo xdebug.profiler_output_name=cachegrind.out.%t.%p >> /etc/php5/apache2/conf.d/20-xdebug.ini;\
    echo xdebug.profiler_output_dir=/tmp/ >> /etc/php5/apache2/conf.d/20-xdebug.ini;

# Webgrind
RUN curl -SL https://github.com/alpha0010/webgrind/archive/${WEBGRIND_VERSION}.tar.gz \
    | tar zxvC /opt/ \
    && cd /opt/webgrind-${WEBGRIND_VERSION} \
    && sed -i -e "s#dotExecutable = '/usr/local/bin/dot'#dotExecutable = '/usr/bin/dot'#" config.php \
    && chown -R www-data /opt/webgrind-${WEBGRIND_VERSION}

# SSMTP to mailhog
RUN mkdir -p /usr/bin/;\
  curl -L https://github.com/mailhog/MailHog/releases/download/v${MAILHOG_VERSION}/MailHog_linux_amd64 -o /usr/bin/mailhog;\
  chmod +x /usr/bin/mailhog \
  && sed -i -e 's/mailhub=mail/mailhub=127.0.0.1:1025/' /etc/ssmtp/ssmtp.conf

COPY add-files/root.my.cnf /root/.my.cnf
COPY add-files/phpmyadmin-config.inc.php /etc/phpmyadmin/config.inc.php
COPY add-files/dot.bashrc /root/.bashrc
COPY add-files/startup-in-container.sh /opt/startup-in-container.sh
COPY add-files/debian.cnf /etc/mysql/debian.cnf
COPY add-files/mysql-setup.sql /opt/mysql-setup.sql
COPY add-files/webgrind.conf /etc/apache2/conf.d/webgrind.conf

ENTRYPOINT ["/opt/startup-in-container.sh"]

# So that we at somepoint can do stuff in startup-in-container.sh
CMD ["--dev"]
