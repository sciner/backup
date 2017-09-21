backup
======

Backup web projects by one bash script

Usage examples
======
```
log "start\n"

backupDir apache2 /etc/apache2
backupDir nginx /etc/nginx
backupDir network /etc/network
backupDir php5 /etc/php5

backupMongoDb 127.0.0.1

# Store all DB to separated archive
backupPgsqlRecv

# Store all directories to separated archive
backupDirRecv /var/www

# backupMysql  $mysql_host $mysql_user $mysql_pass --all_databases
backupMysql  $mysql_host $mysql_user $mysql_pass sales
backupMysql  $mysql_host $mysql_user $mysql_pass mysql
backupMysql  $mysql_host $mysql_user $mysql_pass redmine
backupMysql  $mysql_host $mysql_user $mysql_pass information_schema

sendLog
```
