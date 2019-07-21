#!/bin/bash

# base directory for mariadb backups
backups=/backup/cluster
user=ccsbackups
pass=backupsRock!
clusterip=10.1.1.10
clusterport=3309

# determine today
wd=`date +'%u'`
md=`date +'%d'`
mo=`date +'%m'`
# in most months, fridays after the 24th will be the last
last=24
# in 30 day months, its the 23rd
if [ $mo -eq 9 -o $mo -eq 4 -o $mo -eq  6 -o $mo -eq 11 ]
then
    last=23
fi
# in feb its the 21st (except leap years, but I dont care
if [ $mo -eq 2 ]
then
    last=21
fi

# do level 1 backups every day except the last friday of the month -
# then do level 0
level=1
if [ $wd -eq 5 -a $md -gt $last ]
then
    level=0
fi

if [ "$1" == "-f" ]
then
    level=0
    shift
fi

thedir=`date +"%Y-%m-%d-%T"`

file=/backup/dbbackup.pid

if [ -f $file ]
then
    if pgrep xtrabackup 
    then
        echo "backups already running (xtrabackup)!";
        exit 1;
    fi
fi

echo $$ > $file

echo "Running Xtrabackup at " `date`
mkdir $backups/$thedir
cp /dev/null /tmp/dbbackup.log
for db in beacons beacons000007 beacons000015 beacons000029 beacons000034
do
    mkdir $backups/$db
    args="--no-defaults --datadir=/var/lib/mysql -S /var/run/mysqld/mysqld.sock --backup --databases=$db --target-dir=$backups/$thedir/$db --rsync -u $user --password=$pass -h $clusterip -P $clusterport --history"

    if [ $level == 1 ]
    then
        args="$args --incremental-basedir=$backups/$db/lastfull"
    fi

    echo "args is $args"


    xtrabackup $args >> /tmp/dbbackup.log 2>&1 
    mysqldump -u $user -p$pass -d $db > $backups/$thedir/$db/$db.sql
    status=$?
    echo "Backup of $db complete with status of $status at " `date`
    if [ $level == 0 ]
    then
        rm -f $backups/$db/lastfull
        ln -s $backups/$thedir/$db $backups/$db/lastfull
    else
        rm -f $backups/$db/lastincremental
        ln -s $backups/$thedir/$db $backups/$db/lastincremental 
    fi
done



date
rm $file
echo "Backup complete"
