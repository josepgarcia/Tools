#!/bin/bash

BACKUP_DIR=/tmp/mysqlBackup
MYSQL_USER=root
MYSQL_PASSWORD=root
MYSQL_HOST=localhost
MYSQL_PORT=3306
#MYSQL_CMD=/Applications/MAMP/Library/bin/mysql
MYSQL_CMD=/opt/homebrew/opt/mysql/bin/mysql
MYSQL_DUMP=/Applications/MAMP/Library/bin/mysqldump
#MYSQL_DUMP=/opt/homebrew/bin/mysqldump
IGNORE_DB="(^mysql|_schema$)"

######################################################
# YYYY-MM-DD
TIMESTAMP=$(date +%F)

mkdir -p $BACKUP_DIR

function mysql_login() {
  local mysql_login="-u $MYSQL_USER -p$MYSQL_PASSWORD"
  echo $mysql_login
}

function echo_status(){
  printf '\r';
  printf ' %0.s' {0..100}
  printf '\r';
  printf "$1"'\r'
}

function hr(){
  printf '=%.0s' {1..100}
  printf "\n"
}

function database_list() {
  local show_databases_sql="SHOW DATABASES WHERE \`Database\` NOT REGEXP '$IGNORE_DB'"
  echo $($MYSQL_CMD $(mysql_login) -e "$show_databases_sql"|awk -F " " '{if (NR!=1) print $1}')
}

function backup_database(){
    backup_file="$BACKUP_DIR/$database.sql.gz"
    output+="$database => $backup_file\n"
    echo_status "...backing up $count of $total databases: $database"
    $($MYSQL_DUMP $(mysql_login) $database | gzip -9 > $backup_file)
}

function create_database(){
    local create_database_sql="CREATE DATABASE IF NOT EXISTS $restoreDb"
    $($MYSQL_CMD $(mysql_login) -e "$create_database_sql")
    echo_status "...creating $restoreDb"
    echo_status "...$restoreDb created"
}

function restore_database(){
  backup_file="$BACKUP_DIR/$restoreDb.sql.gz"
  if [[ -f $backup_file ]]; then
    create_database
    echo "...restoring $restoreDb"
    echo $(gunzip < $backup_file | $MYSQL_CMD $(mysql_login) $restoreDb )
  else
    echo "...$restoreDb not exists"
  fi
}

function backup_databases(){
  local databases=$(database_list)
  local total=$(echo $databases | wc -w | xargs)
  local output=""
  local count=1
  for database in $databases; do
    backup_database
    local count=$((count+1))
  done
  echo -ne $output | column -t
}

if [[ $# -ne 1 &&  $# -ne 2 ]]; then
  echo "Usage: $0 <backup|restore dbname>"
fi

if [[ $1 == "backup" ]]; then
  echo "DESACTIVADO"
  exit
  hr
  printf "Starting MySQL Backup\n"
  backup_databases
  printf "All backed up!\n\n"
  hr
elif [[ $1 == "restore" ]]; then
  if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <backup|restore dbname>"
  fi
  restoreDb=$2
  restore_database
  hr

else
  echo "Usage: $0 <backup|restore dbname>"
  exit 1
fi

exit 0
