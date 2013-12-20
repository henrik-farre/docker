#!/bin/sh

IMAGE='enrique/localdev'

mailcatcher --smtp-ip 172.17.42.1

docker run -i -t -p 80:80 -v $(pwd)/var-www:/var/www -v $(pwd)/var-lib-mysql:/var/lib/mysql -v $(pwd)/etc-apache2-sites-enabled:/etc/apache2/sites-enabled $IMAGE
