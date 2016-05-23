#!/bin/bash

service apache2 start
/usr/bin/mailhog &

# Run Drupal Console init here, so /var/www is mounted outside
if [ ! -d /var/www/.console ]; then
  mkdir /var/www/.console
  chown www-data: /var/www/.console
  su - www-data -c "/usr/bin/drupal init"
fi

tail -f /var/log/apache2/*.log
