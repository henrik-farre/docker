#!/bin/bash

service ssh start
service mysql start
service apache2 start

tail -f /var/log/apache2/*.log
