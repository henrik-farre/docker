#!/bin/bash

# Create db if it does not exist
if [[ ! -f /var/lib/mysql/ib_logfile0 ]]; then
  mysql_install_db
  mysqld_safe --skip-grant-tables &
  until mysqladmin ping &>/dev/null; do
    echo -n "."; sleep 0.2
  done
  gunzip -c /usr/share/doc/phpmyadmin/examples/create_tables.sql.gz | mysql
  mysql mysql < /opt/mysql-setup.sql
  mysqladmin shutdown
fi

service mysql start
service apache2 start
/usr/bin/mailhog &

tail -f /var/log/apache2/*.log
