#!/bin/bash

set -euo pipefail

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPTPATH="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
source "$SCRIPTPATH/common.sh"

###############################################

if ! [[ $# -eq 1 ]]; then
  echo 'Necesario 1 parámetro, nombre del proyecto'
  exit 1
fi
validate_project_name "$1"


clear
echo -e "${BLUE}"
echo "+---------------------+"
echo "|   SETUP ENVIRONMENT |"
echo "+---------------------+"
echo -e "${NC}"

# Validar que MySQL esté corriendo y se pueda conectar
printf '\nChecking MySQL connection...\n'
if ! check_mysql_connection; then
  echo -e "${RED}ERROR: No se puede conectar a MySQL ❌${NC}"
  echo "Verifica que:"
  echo "  - MySQL esté corriendo (brew services start mysql)"
  echo "  - Las credenciales en common.sh sean correctas"
  echo "  - El puerto sea el correcto"
  exit 1
fi
echo -e "${GREEN}MySQL connection OK ✅${NC}"

# Verificar si la base de datos ya existe
printf '\nChecking if database exists...\n'
if check_database_exists "$DBNAME"; then
  echo -e "${RED}ERROR: La base de datos '$DBNAME' ya existe ❌${NC}"
  exit 1
fi

printf '\nCreating database...\n'
DBNAME_SQL=$(quote_identifier "$DBNAME")
if ! "$mysqlbin" "${MYSQL_OPTS[@]}" -e "CREATE DATABASE $DBNAME_SQL CHARACTER SET utf8 COLLATE utf8_general_ci;" 2>/dev/null; then
  echo -e "${RED}ERROR: No se pudo crear la base de datos ❌${NC}"
  exit 1
fi
echo -e "${GREEN}Database created ✅${NC}"

# Verificar si la carpeta ya existe
if [[ -d "$DIRNAME" ]]; then
  echo -e "${RED}ERROR: La carpeta '$DIRNAME' ya existe ❌${NC}"
  exit 1
fi

printf '\nCreating folder...\n'
if ! mkdir "$DIRNAME"; then
  echo -e "${RED}ERROR: No se pudo crear la carpeta ❌${NC}"
  exit 1
fi
echo -e "${GREEN}Folder created ✅${NC}"

printf '\n'
echo -e "${GREEN}Environment setup completed 🙌${NC}"
printf '\n'

cd "$DIRNAME"
