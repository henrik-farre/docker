#!/bin/bash

# The password for the debian-sys-maint user follows the container, and is auto generated when installed
# and it is set in MySQL where the data is stored in a volume, and therefor persists
DEBIAN_SYS_MAINT_PASS_1=$(awk '$1 ~ /password/ {print $3;exit}' /etc/mysql/debian.cnf)
if [[ ! -f /var/lib/mysql/.debian_sys_maint_pass ]]; then
  echo $DEBIAN_SYS_MAINT_PASS_1 > /var/lib/mysql/.debian_sys_maint_pass
fi

DEBIAN_SYS_MAINT_PASS_2=$(cat /var/lib/mysql/.debian_sys_maint_pass)

service mysql start

if [[ $DEBIAN_SYS_MAINT_PASS_1 != $DEBIAN_SYS_MAINT_PASS_2 ]]; then
  until mysqladmin ping &>/dev/null; do
    echo -n "."; sleep 0.2
  done
  echo "Resetting debian sys maint password"
  mysql -u root mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'debian-sys-maint'@'localhost' IDENTIFIED BY '$DEBIAN_SYS_MAINT_PASS_1' WITH GRANT OPTION; FLUSH PRIVILEGES;"
  echo $DEBIAN_SYS_MAINT_PASS_1 > /var/lib/mysql/.debian_sys_maint_pass
  sleep 1
  service mysql restart
fi

# Setup phpmyadmin again, once
if [[ ! -f /var/lib/mysql/.setup-ok ]]; then
  echo "Creating phpMyAdmin tables and users"
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
