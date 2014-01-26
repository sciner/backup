#!/bin/bash

TO="/tmp"
DIR=`/bin/date +%Y-%m-%d`
FTPS='frp server'
FTPU='ftp user'
FTPP='frp password'
/usr/bin/lftp -u $FTPU,$FTPP $FTPS -e "mkdir $DIR;quit"

mysql_host=''
mysql_user=''
mysql_pass=''

LOGDATE=`/bin/date +%Y-%m-%d-%H-%M-%S`
LOG=$TO/backup_$LOGDATE.log

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
    sendFile2ftp $LOG
}

function sendFile2ftp() {
    /usr/bin/lftp -u $FTPU,$FTPP $FTPS -e "cd $DIR;mput $1;quit"
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
    sendFile2ftp $COMPRESSED
    E=$(getElapsed)
    log "$E\tsent to ftp\n"

    # 4) remove compressed file
    /bin/rm $COMPRESSED

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

log "start\n"
backupDir apache2 /etc/apache2
backupDir nginx /etc/nginx
backupDir network /etc/network
backupDir php5 /etc/php5
# backupMysql  $mysql_host $mysql_user $mysql_pass --all_databases
backupMysql  $mysql_host $mysql_user $mysql_pass sales
backupMysql  $mysql_host $mysql_user $mysql_pass mysql
backupMysql  $mysql_host $mysql_user $mysql_pass redmine
backupMysql  $mysql_host $mysql_user $mysql_pass information_schema
sendLog
