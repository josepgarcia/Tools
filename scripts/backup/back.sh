#!/bin/bash

# Script para hacer backup de cada base de datos de MySQL de forma individual
# Uso: chmod +x backup_mysql.sh && ./backup_mysql.sh

# ConfiguraciÃ³n
MYSQL_USER="root"
MYSQL_PASSWORD="root" # Cambia si tienes contraseÃ±a
MYSQL_HOST="localhost"
BACKUP_DIR="./mysql_backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
MYSQLDUMP="/opt/homebrew/opt/mysql/bin/mysqldump"
MYSQL="/opt/homebrew/opt/mysql/bin/mysql"

# Crear directorio de backups si no existe
mkdir -p "$BACKUP_DIR"

# Colores para output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Iniciando Backup de Bases de Datos MySQL ===${NC}"
echo "Directorio de backup: $BACKUP_DIR"
echo "Timestamp: $TIMESTAMP"
echo ""

# Obtener lista de bases de datos
if [ -z "$MYSQL_PASSWORD" ]; then
  DATABASES=$($MYSQL -u "$MYSQL_USER" -h "$MYSQL_HOST" -e "SHOW DATABASES;" 2>/dev/null | grep -v "Database" | grep -v "^|" | awk '{print $1}')
else
  DATABASES=$($MYSQL -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -h "$MYSQL_HOST" -e "SHOW DATABASES;" 2>/dev/null | grep -v "Database" | grep -v "^|" | awk '{print $1}')
fi

# Verificar si se obtuvieron las bases de datos
if [ -z "$DATABASES" ]; then
  echo -e "${RED}Error: No se pudieron obtener las bases de datos${NC}"
  echo "Verifica que MySQL estÃ© corriendo y las credenciales sean correctas"
  exit 1
fi

# Contar total de bases de datos
DB_COUNT=$(echo "$DATABASES" | wc -l)
echo -e "${YELLOW}Total de bases de datos encontradas: $DB_COUNT${NC}"
echo ""

# Contadores
SUCCESS=0
FAILED=0

# Iterar sobre cada base de datos
for DB in $DATABASES; do
  # Saltar bases de datos del sistema
  if [[ "$DB" == "information_schema" ]] || [[ "$DB" == "mysql" ]] || [[ "$DB" == "performance_schema" ]] || [[ "$DB" == "sys" ]]; then
    echo -e "${YELLOW}Omitiendo base de datos del sistema: $DB${NC}"
    continue
  fi

  BACKUP_FILE="$BACKUP_DIR/${DB}_${TIMESTAMP}.sql"

  echo -n "Haciendo backup de: $DB ... "

  # Ejecutar mysqldump
  if [ -z "$MYSQL_PASSWORD" ]; then
    $MYSQLDUMP -u "$MYSQL_USER" -h "$MYSQL_HOST" "$DB" >"$BACKUP_FILE" 2>/dev/null
  else
    $MYSQLDUMP -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -h "$MYSQL_HOST" "$DB" >"$BACKUP_FILE" 2>/dev/null
  fi

  # Verificar si el backup fue exitoso
  if [ $? -eq 0 ]; then
    SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    echo -e "${GREEN}OK${NC} (TamaÃ±o: $SIZE)"
    ((SUCCESS++))
  else
    echo -e "${RED}FALLÃ“${NC}"
    rm -f "$BACKUP_FILE"
    ((FAILED++))
  fi
done

echo ""
echo -e "${YELLOW}=== Resumen ===${NC}"
echo -e "Backups exitosos: ${GREEN}$SUCCESS${NC}"
echo -e "Backups fallidos: ${RED}$FAILED${NC}"
echo "Directorio de backups: $BACKUP_DIR"
echo ""

# Listar archivos creados
if [ $SUCCESS -gt 0 ]; then
  echo -e "${YELLOW}Archivos creados:${NC}"
  ls -lh "$BACKUP_DIR" | grep "\.sql$"
fi
