<VirtualHost *:80>
  <Directory /var/www/[DOMAIN.TLD]/>
    AllowOverride All
    Options FollowSymLinks
    Order Allow,Deny
    Allow from ALL
  </Directory>

  ServerName [DOMAIN.TLD]
  ServerAlias www.[DOMAIN.TLD]

  DocumentRoot /var/www/[DOMAIN.TLD]/public_html/

  CustomLog /var/www/[DOMAIN.TLD]/logs/access.log combined
  ErrorLog /var/www/[DOMAIN.TLD]/logs/error.log

  php_admin_value open_basedir /var/www/[DOMAIN.TLD]/:/usr/share/pear
  php_admin_value upload_tmp_dir /var/www/[DOMAIN.TLD]/upload
  php_value include_path .:/usr/share/pear

  php_value log_errors 1
  php_value error_reporting 2047
  php_value error_log /var/www/[DOMAIN.TLD]/logs/php.log

  php_value session.save_path /var/www/[DOMAIN.TLD]/sessions
</VirtualHost>
