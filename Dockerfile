FROM tianon/debian:wheezy
MAINTAINER Henrik Farre <henrik@rockhopper.dk>

ENV DEBIAN_FRONTEND noninteractive
ENV DEBIAN_PRIORITY critical
ENV DEBCONF_NOWARNINGS yes
ENV MYSQL_PASS my5QLpw

# Default config
RUN echo tzdata tzdata/Areas select Europe | debconf-set-selections; \
  echo tzdata tzdata/Zones/Europe select Copenhagen | debconf-set-selections; \
  echo mysql-server mysql-server/root_password password ${MYSQL_PASS} | debconf-set-selections;\
  echo mysql-server mysql-server/root_password_again password ${MYSQL_PASS} | debconf-set-selections;\
  echo phpmyadmin phpmyadmin/app-password-confirm password | debconf-set-selections;\
  echo phpmyadmin phpmyadmin/dbconfig-install boolean true | debconf-set-selections;\
  echo phpmyadmin phpmyadmin/mysql/admin-pass password ${MYSQL_PASS} | debconf-set-selections;\
  echo phpmyadmin phpmyadmin/mysql/app-pass password ${MYSQL_PASS} | debconf-set-selections;\
  echo phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2 | debconf-set-selections;

# Update and install
RUN apt-get -q -y update
RUN apt-get -q -y upgrade
RUN apt-get -q -y install ssh ssmtp vim pwgen locales apache2 mysql-server phpmyadmin php5-dev make libapache2-mod-php5 php-apc php5-tidy php5-curl php-pear php5-xdebug curl php5-mcrypt php5-sqlite imagemagick 

# System
RUN echo "root:root" | chpasswd
RUN sed -i -e 's/# da_DK.UTF-8/da_DK.UTF-8/' /etc/locale.gen
RUN locale-gen

# Apache
RUN echo "ServerName localdev" | tee /etc/apache2/conf.d/fqdn
RUN a2enmod rewrite;\
  a2enmod php5

# echo apc.rfc1867=on >> /etc/php5/apache2/conf.d/apc.ini

# cat << 'EOF' > /root/.my.cnf
# [client]
# user=root
# host=localhost
# password='${MYSQL_PASS}'
# EOF

# Drush for Drupal
RUN pear upgrade PEAR;\
  pear channel-discover pear.drush.org;\
  pear install drush/drush

# PHP settings
RUN sed -i -e 's/post_max_size = 8M/post_max_size = 200M/' /etc/php5/apache2/php.ini
RUN sed -i -e 's/upload_max_filesize = 2M/upload_max_filesize = 200M/' /etc/php5/apache2/php.ini
RUN sed -i -e 's/;date.timezone =/date.timezone = Europe\/Copenhagen/' /etc/php5/apache2/php.ini
# - xdebug
RUN echo xdebug.remote_enable=1 >> /etc/php5/conf.d/20-xdebug.ini;\
  echo xdebug.remote_autostart=0 >> /etc/php5/conf.d/20-xdebug.ini;\
  echo xdebug.remote_connect_back=1 >> /etc/php5/conf.d/20-xdebug.ini;\
  echo xdebug.remote_port=9000 >> /etc/php5/conf.d/20-xdebug.ini;\
  echo xdebug.remote_log=/tmp/php5-xdebug.log >> /etc/php5/conf.d/20-xdebug.ini;

# SSMTP to mailcatcher
RUN sed -i -e 's/mailhub=mail/mailhub=172.17.42.1:1025/' /etc/ssmtp/ssmtp.conf

ADD ./startup.sh /opt/startup.sh

ENTRYPOINT ["/opt/startup.sh"]

# So that we at somepoint can do stuff in startup.sh
CMD ["--dev"]
