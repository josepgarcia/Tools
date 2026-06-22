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
  echo 'Necesario 1 parámetro, nombre del proyecto (sin wp delante)'
  exit 1
fi
validate_project_name "$1"

clear
echo -e "${BLUE}"
echo "+---------------------+"
echo "| Deleting Wordpress  |"
echo "+---------------------+"
echo -e "${NC}"

# Validar que MySQL esté corriendo y se pueda conectar
printf '\nChecking MySQL connection...\n'
if ! check_mysql_connection; then
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
  DBNAME_SQL=$(quote_identifier "$DBNAME")
  if "$mysqlbin" "${MYSQL_OPTS[@]}" -e "DROP DATABASE $DBNAME_SQL;" 2>/dev/null; then
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
if [[ ! -d "$DIRNAME" ]]; then
  echo -e "${YELLOW}WARNING: La carpeta no existe${NC}"
else
  if rm -rf -- "$DIRNAME" 2>/dev/null; then
    echo -e "${GREEN}Folder deleted ✅${NC}"
  else
    echo -e "${RED}ERROR: No se pudo eliminar la carpeta ❌${NC}"
    exit 1
  fi
fi
printf '\n'
echo -e "${GREEN}Process completed 🙌${NC}"
####################
