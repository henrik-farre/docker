#!/bin/bash

service mysql start

# Setup phpmyadmin again, once
if [[ ! -f /var/lib/mysql/.setup-ok ]]; then
   until mysqladmin ping &>/dev/null; do
     echo -n "."; sleep 0.2
   done
   gunzip -c /usr/share/doc/phpmyadmin/examples/create_tables.sql.gz | mysql
   mysql mysql < /opt/mysql-setup.sql
   touch /var/lib/mysql/.setup-ok
fi

service apache2 start
/usr/bin/mailhog &

tail -f /var/log/apache2/*.log
