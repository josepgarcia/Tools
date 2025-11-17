#!/bin/bash

SCRIPTPATH=$(dirname "$0")
source $SCRIPTPATH/config.file

###############################################

if ! [[ $# -eq 1 ]]; then
  echo 'Necesario 1 parámetro, nombre del proyecto (sin wp delante)'
  exit 1
fi

clear
echo -e "${BLUE}"
echo "+---------------------+"
echo "| Deleting Wordpress  |"
echo "+---------------------+"
echo -e "${NC}"

########### DATABASE
printf '\n'
echo "Removing DB"
#if [[ $? -eq 0 ]]
#then
  $mysqlbin -u $DBUSER -p$DBPASS -e "DROP DATABASE $DBNAME;" 2> /dev/null
  echo -e "${GREEN}Done! ✅${NC}"
#else
#  echo -e "${RED}La BD no existe ✅${NC}"
#fi
printf '\n'
####################


########### FOLDER
printf '\n'
echo "Removing FOLDER"
if [[ ! -d $DIRNAME ]]; then
  echo -e "${RED}Folder does not exist ❌${NC}"
else
  rm -rf $DIRNAME 2> /dev/null
  echo -e "${GREEN}Done! ✅${NC}"
fi
printf '\n'
####################

