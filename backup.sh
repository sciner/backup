#!/bin/bash

TO="/tmp"
CODE="omsk"
DIR=`/bin/date +$CODE/%Y-%m-%d/%H-%M`
LOGDATE=`/bin/date +%Y-%m-%d-%H-%M-%S`
LOG=$TO/backup_$LOGDATE.log

#FTP
    FTPU='user'
    FTPP='password'
    FTPS='host'
    /usr/bin/lftp -u $FTPU,$FTPP $FTPS -e "mkdir $DIR;quit"

#PostgreSQL
    pgu=user
    pgp='password'

#SSH
    sshu='user'
    sshp='password'
    sshs='host'
    sshd='/var/backups'
    sshpass -p $sshp ssh $sshu:$sshp@$sshs mkdir -p $sshd/$DIR

# MySQL
    mysql_host='host'
    mysql_user='user'
    mysql_pass='password'

function startTimer() {
    STARTTIME=$(date +%s)
}

function getElapsed() {
    ENDTIME=$(date +%s)
    ELPSD="$[$ENDTIME - $STARTTIME]"
    M=$[$ELPSD/60]
    S=$[$ELPSD%60]
    echo "$M:$S"
}

function log() {
    if [ "$1" != '' ]; then
        DATE=`/bin/date "+%Y.%m.%d %H:%M:%S"`
        echo -e $DATE $1>>$LOG
    else
        echo>>$LOG
    fi
}

function sendLog() {
    sendFile2ssh $LOG
}

function sendFile2ftp() {
    /usr/bin/lftp -u $FTPU,$FTPP $FTPS -e "cd $DIR;mput $1;quit"
}

function sendFile2ssh() {
    sshpass -p $sshp scp $1 -r $sshu@$sshs:$sshd/$DIR/
}

function backupDir() {

    # 1) preparing
    DATE=`/bin/date +%Y%m%d-%H%M`
    SOURCE=$2
    COMPRESSED=$TO/directory_$1_$DATE.tar.gz

    # 2) compress directory
    startTimer
    tar -C $2 -czpf $COMPRESSED $SOURCE
    E=$(getElapsed)
    log "$E\tdirectory compress $2 to $COMPRESSED"

    # 3) send to FTP
    startTimer
    sendFile2ssh $COMPRESSED
    E=$(getElapsed)
    log "$E\tsent to ftp\n"

    # 4) remove compressed file
    /bin/rm $COMPRESSED

}

function backupDirRecv() {
    for f in $1/*; do
	backupDir $(basename "$f") $f
    done;
}

function backupMysql() {

    # 1) preparing
    DATE=`/bin/date +%Y%m%d-%H%M`
    COMPRESSED=$TO/mysql_$4_$DATE.tar.gz
    SOURCE=$TO/mysql-$DATE.sql
    
    # 2) dump DB
    startTimer
    mysqldump -h $1 -u $2 -p$3 $4 | gzip > $COMPRESSED
    E=$(getElapsed)
    log "$E\tmysql dump $4 to $COMPRESSED"

    # 3) send to FTP
    startTimer
    sendFile2ftp $COMPRESSED
    E=$(getElapsed)
    log "$E\tsent to ftp\n"

    # 4) remove compressed file
    /bin/rm $COMPRESSED

}

function backupPgsqlRecv() {
    
    # 1) preparing
    PGPASSWORD=$pgp
    export PGPASSWORD

    # 2) get databases list
    DBS="$(psql -U $pgu -lt |awk '{ print $1}' |grep -vE '^-|^List|^Name|template[0|1]')"

    for db in $DBS
    do
	if [ "$db" != '|' ]; then
	    
	    # 3) dump DB
	    startTimer
	    DATE=`/bin/date +%Y%m%d-%H%M`
	    COMPRESSED=$TO/pgsql_$db\_$DATE.sql.gz
    	    pg_dump -U $pgu $db | gzip -c > $COMPRESSED
	    E=$(getElapsed)
	    log "$E\tpgsql dump $db to $COMPRESSED"
	    
	    # 4) send to backup server
	    startTimer
	    sendFile2ssh $COMPRESSED
	    E=$(getElapsed)
	    log "$E\tsent to backup server\n"
	    
	    # 5) remove compressed file
	    /bin/rm $COMPRESSED

	fi
    done

    # 6) finalize
    PGPASSWORD=
    export PGPASSWORD

}

function backupMongoDb() {

    # 1) preparing
    DATE=`/bin/date +%Y%m%d-%H%M`
    OUT_DIR=$TO/mongodb_$DATE

    # 2) dump DB
    startTimer
    mongodump -h $1 -out $OUT_DIR
    E=$(getElapsed)
    log "$E\tmongodb dump $4 to directory $OUT_DIR"

    backupDirRecv $OUT_DIR

    # 4) remove directory
    /bin/rm -r -f $OUT_DIR

}

# USAGE EXAMPLE:

# log "start\n"
#
# backupDir apache2 /etc/apache2
# backupDir nginx /etc/nginx
# backupDir network /etc/network
# backupDir php5 /etc/php5
#
# backupMongoDb 127.0.0.1
#
# # Store all DB to separated archive
# backupPgsqlRecv
#
# # Store all directories to separated archive
# backupDirRecv /var/www
#
# # backupMysql  $mysql_host $mysql_user $mysql_pass --all_databases
# backupMysql  $mysql_host $mysql_user $mysql_pass sales
# backupMysql  $mysql_host $mysql_user $mysql_pass mysql
# backupMysql  $mysql_host $mysql_user $mysql_pass redmine
# backupMysql  $mysql_host $mysql_user $mysql_pass information_schema
#
# sendLog
