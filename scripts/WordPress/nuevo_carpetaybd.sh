#!/bin/bash

SCRIPTPATH=$(dirname "$0")
source $SCRIPTPATH/config.file

###############################################

if ! [[ $# -eq 1 ]]; then
  echo 'Necesario 1 parámetro, nombre del proyecto'
  exit 1
fi


clear
echo -e "${BLUE}"
echo "+---------------------+"
echo "|      CREATE DB      |"
echo "+---------------------+"
echo -e "${NC}"

printf '\n'
$mysqlbin -u $DBUSER -p$DBPASS -e "CREATE DATABASE $DBNAME CHARACTER SET utf8 COLLATE utf8_general_ci;" 2> /dev/null
echo -e "${GREEN}Done! ✅${NC}"
printf '\n'

mkdir $DIRNAME
printf '\n'
#curl --remote-name --silent --show-error https://wordpress.org/latest.tar.gz
## IF ERROR 
echo -e "${GREEN}Done! ✅${NC}"
printf '\n'

printf '\n'
echo -e "${GREEN}Fantastisch! All done 🙌${NC}";
printf '\n'
printf '\n'

cd $DIRNAME

