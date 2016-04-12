# Docker based local development environment

## Setup

Include bin/ in $PATH or run directly bin/pilotboat directly.

The pilotboat command will build the images and start the containers on first run

## Quick start Drupal 8 site

    pilotboat start php-dev-debian-jessie
    pilotboat site-create domain.tld drupal8

Replace domain.tld with a domain pointing to localhost.

## Supported site types:

    pilotboat site-create domain.tld [SITE_TYPE]

* [None]: if you call site-create with just a domain, you will just get a virtual host, and a directory structure in sites
* Drupal8: Latest version of Drupal 8 is installed
* Drupal7: Latest version of Drupal 7 is installed
* Wordpress: Latest version of Wordpress is installed

## Tools

* Webgrind: http://localhost/webgrind
* Mailhog: http://localhost:8025/
