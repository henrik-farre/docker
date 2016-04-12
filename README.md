# Docker based local development environment

## Setup

Include bin/ in $PATH or run directly bin/pilotboat directly.

The pilotboat command will build the images and start the containers on first run

## Quick start

    pilotboat start php-dev-debian-jessie
    pilotboat site-create domain.tld drupal8

Replace domain.tld with a domain pointing to localhost. The drupal8 argument is optional (will just create a virtual host and directory structure), and can also be drupal7
