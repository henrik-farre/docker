# TODO

Check if container is running before issuing commands

## Pilot commands

### Wordpress
Setup wordpress:
```sql
UPDATE `DB`.`wp_options` SET `option_value` = 'http://local.tld' WHERE `wp_options`.`option_name` = 'siteurl';
```
