#!/bin/bash

SCRIPTPATH=$(dirname "$0")
source $SCRIPTPATH/common.sh

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

# Validar que MySQL esté corriendo y se pueda conectar
printf '\nChecking MySQL connection...\n'
check_mysql_connection
if [ $? -ne 0 ]; then
  echo -e "${RED}ERROR: No se puede conectar a MySQL ❌${NC}"
  echo "Verifica que:"
  echo "  - MySQL esté corriendo"
  echo "  - Las credenciales en common.sh sean correctas"
  exit 1
fi
echo -e "${GREEN}MySQL connection OK ✅${NC}"

########### DATABASE
printf '\nRemoving database...\n'
if ! check_database_exists "$DBNAME"; then
  echo -e "${YELLOW}WARNING: La base de datos '$DBNAME' no existe${NC}"
else
  $mysqlbin -u $DBUSER -p$DBPASS -e "DROP DATABASE $DBNAME;" 2>/dev/null
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}Database deleted ✅${NC}"
  else
    echo -e "${RED}ERROR: No se pudo eliminar la base de datos ❌${NC}"
    exit 1
  fi
fi
printf '\n'
####################


########### FOLDER
printf '\nRemoving folder...\n'
if [[ ! -d $DIRNAME ]]; then
  echo -e "${YELLOW}WARNING: La carpeta no existe${NC}"
else
  rm -rf $DIRNAME 2>/dev/null
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}Folder deleted ✅${NC}"
  else
    echo -e "${RED}ERROR: No se pudo eliminar la carpeta ❌${NC}"
    exit 1
  fi
fi
printf '\n'
echo -e "${GREEN}Process completed 🙌${NC}"
####################

