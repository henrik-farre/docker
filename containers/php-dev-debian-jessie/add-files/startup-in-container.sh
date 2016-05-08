#!/bin/bash

service apache2 start
/usr/bin/mailhog &

tail -f /var/log/apache2/*.log
