#!/bin/sh

IMAGE='enrique/localdev'
NAME="localdev"

MAILCATCHER_IS_RUNNING=`netstat -tna | grep 1025 | wc -l`
if [[ $MAILCATCHER_IS_RUNNING == 0 ]]; then
  mailcatcher --smtp-ip 172.17.42.1
fi

CONTAINER_EXIST=`docker ps -a | cut -c131- | grep -c $NAME`
if [[ $CONTAINER_EXIST > 0 ]]; then
  echo "Restarting docker container $NAME"
  docker restart $NAME
else
  echo "Starting new docker with name $NAME"
  docker run -i -t -p 80:80 -v $(pwd)/var-www:/var/www -v $(pwd)/var-lib-mysql:/var/lib/mysql -v $(pwd)/etc-apache2-sites-enabled:/etc/apache2/sites-enabled -name $NAME $IMAGE
fi
