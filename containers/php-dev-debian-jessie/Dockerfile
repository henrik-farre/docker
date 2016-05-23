FROM debian:jessie
MAINTAINER Henrik Farre <henrik@rockhopper.dk>

ENV DEBIAN_FRONTEND=noninteractive \
  DEBIAN_PRIORITY=critical \
  DEBCONF_NOWARNINGS=yes \
  WEBGRIND_VERSION=1.2 \
  MAILHOG_VERSION=0.2.0 \
  XDEBUG_HOST=172.17.0.1 \
  XDEBUG_PORT=9000 \
  MYSQL_HOST=database \
  MYSQL_USER=root \
  MYSQL_PASS=root \
  WEB_SERVER=APACHE \
  TERM=xterm

# Check local docker0 interface if Vdebug can't connect: ip addr show docker0

# Default config
RUN echo "tzdata tzdata/Areas select Europe" | debconf-set-selections \
 && echo "tzdata tzdata/Zones/Europe select Copenhagen" | debconf-set-selections \
 && echo "locales locales/locales_to_be_generated multiselect     en_US.UTF-8 UTF-8, en_GB.UTF-8 UTF-8, da_DK.UTF-8 UTF-8" | debconf-set-selections \
 && echo "locales locales/default_environment_locale      select  da_DK.UTF-8" | debconf-set-selections

# Update and install
# Python and graphviz for webgrind
# ca-certificates else curl will fail on https
RUN apt-get -q -y update && apt-get -q -y --no-install-recommends upgrade \
 && apt-get -q -y --no-install-recommends install \
      mariadb-client \
      ca-certificates \
      locales \
      apache2 \
      libapache2-mod-php5 \
      curl \
      php-apc \
      php-pear \
      php5-mysql \
      php5-tidy \
      php5-curl \
      php5-xdebug \
      php5-mcrypt \
      php5-sqlite \
      php5-sybase \
      php5-ldap \
      php5-gd \
      imagemagick \
      python \
      graphviz \
 && apt-get clean \
 && rm -rf /var/lib/{apt,dpkg,cache,log}/ /tmp/* /var/tmp/* /var/cache/debconf/* \
 && rm -rf /usr/share/man/?? /usr/share/man/??_* \
 && /bin/echo -e "[client]\nuser=root\nhost=${MYSQL_HOST}\npassword=root" > /root/.my.cnf

# Apache
# Default virtual host is put in conf-enabled as sites-enabled is shared with the host
# Enable shell for www-data
RUN echo "ServerName jessie.localdomain" | tee /etc/apache2/conf-enabled/fqdn.conf \
  && a2enmod rewrite \
  && a2enmod php5 \
  && a2enmod headers \
  && a2enmod expires \
  && ln -s /etc/apache2/sites-available/000-default.conf /etc/apache2/conf-enabled/000-default.conf \
  && /usr/bin/chsh -s /bin/bash www-data

# PHP and Xdebug settings
# max_nesting_level is needed by Drupal 8
RUN sed -i -e 's/post_max_size = 8M/post_max_size = 200M/' /etc/php5/apache2/php.ini \
    && sed -i -e 's/upload_max_filesize = 2M/upload_max_filesize = 200M/' /etc/php5/apache2/php.ini \
    && sed -i -e 's/;date.timezone =/date.timezone = Europe\/Copenhagen/' /etc/php5/apache2/php.ini \
    && sed -i -e 's/;date.timezone =/date.timezone = Europe\/Copenhagen/' /etc/php5/cli/php.ini \
    && echo xdebug.remote_enable=1 >> /etc/php5/apache2/conf.d/20-xdebug.ini;\
    echo xdebug.remote_autostart=1 >> /etc/php5/apache2/conf.d/20-xdebug.ini;\
    echo xdebug.remote_host=${XDEBUG_HOST} >> /etc/php5/apache2/conf.d/20-xdebug.ini;\
    echo xdebug.remote_port=${XDEBUG_PORT} >> /etc/php5/apache2/conf.d/20-xdebug.ini;\
    echo xdebug.remote_log=/tmp/php5-xdebug.log >> /etc/php5/apache2/conf.d/20-xdebug.ini;\
    echo xdebug.profiler_enable=0 >> /etc/php5/apache2/conf.d/20-xdebug.ini;\
    echo xdebug.profiler_enable_trigger=1 >> /etc/php5/apache2/conf.d/20-xdebug.ini;\
    echo xdebug.profiler_output_name=cachegrind.out.%t.%p >> /etc/php5/apache2/conf.d/20-xdebug.ini;\
    echo xdebug.profiler_output_dir=/tmp/ >> /etc/php5/apache2/conf.d/20-xdebug.ini;\
    echo xdebug.max_nesting_level=256 >> /etc/php5/apache2/conf.d/20-xdebug.ini;

# Composer, Drush, WP-cli, Symfony installer, Drupal Console
# http://docs.drush.org/en/master/install/
# http://wp-cli.org/
# http://symfony.com/doc/current/book/installation.html
# https://drupalconsole.com/
RUN curl https://getcomposer.org/installer -LsS | php -- --install-dir=/usr/bin/ --filename=composer \
 && curl http://files.drush.org/drush.phar -LsS -o /usr/bin/drush \
 && chmod +x /usr/bin/drush \
 && su - www-data -c "php /usr/bin/drush core-status" \
 && curl https://drupalconsole.com/installer -LsS -o /usr/bin/drupal \
 && chmod +x  /usr/bin/drupal \
 && curl https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -LsS -o /usr/bin/wp \
 && chmod +x /usr/bin/wp \
 && su - www-data -c "php /usr/bin/wp --info" \
 && curl https://symfony.com/installer -LsS -o /usr/bin/symfony \
 && chmod +x /usr/bin/symfony

# Webgrind
RUN curl -SL https://github.com/alpha0010/webgrind/archive/${WEBGRIND_VERSION}.tar.gz \
    | tar zxvC /opt/ \
    && cd /opt/webgrind-${WEBGRIND_VERSION} \
    && sed -i -e "s#dotExecutable = '/usr/local/bin/dot'#dotExecutable = '/usr/bin/dot'#" config.php \
    && chown -R www-data /opt/webgrind-${WEBGRIND_VERSION}

# Blackfire
# Based on https://blackfire.io/docs/integrations/docker (echo -e problem: https://github.com/docker/docker/issues/8949)
RUN version=$(php -r "echo PHP_MAJOR_VERSION.PHP_MINOR_VERSION;") \
    && curl -A "Docker" -o /tmp/blackfire-probe.tar.gz -D - -L -s https://blackfire.io/api/v1/releases/probe/php/linux/amd64/$version \
    && tar zxpf /tmp/blackfire-probe.tar.gz -C /tmp \
    && mv /tmp/blackfire-*.so $(php -r "echo ini_get('extension_dir');")/blackfire.so \
    && /bin/echo -e "extension=blackfire.so\nblackfire.agent_socket=tcp://blackfire:8707" > /etc/php5/apache2/conf.d/blackfire.ini \
    && /bin/echo -e "extension=blackfire.so\nblackfire.agent_socket=tcp://blackfire:8707" > /etc/php5/cli/conf.d/blackfire.ini

# SSMTP to mailhog
RUN mkdir -p /usr/bin/;\
  curl -L https://github.com/mailhog/MailHog/releases/download/v${MAILHOG_VERSION}/MailHog_linux_amd64 -o /usr/bin/mailhog \
  && chmod +x /usr/bin/mailhog \
  && sed -i -e 's#;sendmail_path =#sendmail_path =/usr/bin/mailhog sendmail#' /etc/php5/apache2/php.ini \
  && sed -i -e 's#;sendmail_path =#sendmail_path =/usr/bin/mailhog sendmail#' /etc/php5/cli/php.ini

COPY containers/php-dev-debian-jessie/add-files/dot.bashrc /root/.bashrc
COPY containers/php-dev-debian-jessie/add-files/startup-in-container.sh /sbin/start.sh
COPY containers/php-dev-debian-jessie/add-files/webgrind.conf /etc/apache2/conf-enabled/webgrind.conf
COPY bin/docker-cmd /usr/bin/docker-cmd
COPY bin/includes/utils.sh /usr/bin/utils.sh
