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
echo "|   SETUP ENVIRONMENT |"
echo "+---------------------+"
echo -e "${NC}"

# Validar que MySQL esté corriendo y se pueda conectar
printf '\nChecking MySQL connection...\n'
$mysqlbin -u $DBUSER -p$DBPASS -e '\q' &>/dev/null
if [ $? -ne 0 ]; then
  echo -e "${RED}ERROR: No se puede conectar a MySQL ❌${NC}"
  echo "Verifica que:"
  echo "  - MySQL esté corriendo (brew services start mysql)"
  echo "  - Las credenciales en config.file sean correctas"
  echo "  - El puerto sea el correcto"
  exit 1
fi
echo -e "${GREEN}MySQL connection OK ✅${NC}"

# Verificar si la base de datos ya existe
printf '\nChecking if database exists...\n'
DB_EXISTS=$($mysqlbin -u $DBUSER -p$DBPASS -e "SHOW DATABASES LIKE '$DBNAME';" 2>/dev/null | grep "$DBNAME")
if [ ! -z "$DB_EXISTS" ]; then
  echo -e "${RED}ERROR: La base de datos '$DBNAME' ya existe ❌${NC}"
  exit 1
fi

printf '\nCreating database...\n'
$mysqlbin -u $DBUSER -p$DBPASS -e "CREATE DATABASE $DBNAME CHARACTER SET utf8 COLLATE utf8_general_ci;" 2>/dev/null
if [ $? -ne 0 ]; then
  echo -e "${RED}ERROR: No se pudo crear la base de datos ❌${NC}"
  exit 1
fi
echo -e "${GREEN}Database created ✅${NC}"

# Verificar si la carpeta ya existe
if [[ -d $DIRNAME ]]; then
  echo -e "${RED}ERROR: La carpeta '$DIRNAME' ya existe ❌${NC}"
  exit 1
fi

printf '\nCreating folder...\n'
mkdir $DIRNAME
if [ $? -ne 0 ]; then
  echo -e "${RED}ERROR: No se pudo crear la carpeta ❌${NC}"
  exit 1
fi
echo -e "${GREEN}Folder created ✅${NC}"

printf '\n'
echo -e "${GREEN}Environment setup completed 🙌${NC}"
printf '\n'

cd $DIRNAME

