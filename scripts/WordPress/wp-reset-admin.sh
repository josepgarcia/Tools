#!/bin/bash

set -euo pipefail

#######################################################
# WordPress Reset Admin User
#
# Este script resetea el usuario administrador (ID=1)
# con credenciales por defecto para acceso de emergencia
#
# Debe ejecutarse dentro de una carpeta con WordPress
# (donde exista wp-config.php)
#######################################################

# wp-reset-admin.sh
# Resets the password for the admin user (user_id 1 by default)
# Usage: ./wp-reset-admin.sh [user_id]

SCRIPTPATH=$(dirname "$0")
# Source common logic
source "$SCRIPTPATH/common.sh"

echo -e "${BLUE}"
echo "+-------------------------+"
echo "|   RESET ADMIN USER      |"
echo "+-------------------------+"
echo -e "${NC}"

# Verificar que existe wp-config.php en el directorio actual
if [ ! -f "wp-config.php" ]; then
  echo -e "${RED}ERROR: No se encontró wp-config.php en el directorio actual ❌${NC}"
  echo ""
  echo "Este script debe ejecutarse desde la raíz de una instalación de WordPress."
  echo "Asegúrate de estar en la carpeta correcta."
  exit 1
fi
echo -e "${GREEN}wp-config.php encontrado ✅${NC}"

# Extraer datos de conexión desde wp-config.php
printf '\nLeyendo configuración de wp-config.php...\n'
get_db_credentials_from_config
TABLE_PREFIX=$(grep '^\$table_prefix' wp-config.php | sed -E "s/.*=\s*['\"]([^'\"]*)['\"].*/\1/")

# Usar prefijo por defecto si no se encontró
if [ -z "$TABLE_PREFIX" ]; then
  TABLE_PREFIX="wp_"
fi

# Defaults
DEFAULT_LOGIN="admin"
DEFAULT_PASS="123123"
DEFAULT_EMAIL="admin@admin.com"

# 2. Get User ID (Default: 1)
USER_ID=${1:-1}

echo -e "${GREEN}Configuración leída correctamente ✅${NC}"
echo ""
echo -e "  DB_NAME:      ${YELLOW}$DBNAME${NC}"
echo -e "  DB_USER:      ${YELLOW}$DBUSER${NC}"
echo -e "  DB_HOST:      ${YELLOW}$DBHOST${NC}"
echo -e "  TABLE_PREFIX: ${YELLOW}$TABLE_PREFIX${NC}"
echo -e "  Usuario ID:   ${YELLOW}$USER_ID${NC}"
echo ""

MYSQL_OPTS=$(get_mysql_opts)
MYSQL_CMD="$mysqlbin $MYSQL_OPTS"

# Validar que MySQL esté corriendo y se pueda conectar
printf 'Checking MySQL connection...\n'
if ! $MYSQL_CMD -e '\q' &>/dev/null; then
  echo -e "${RED}ERROR: No se puede conectar a MySQL ❌${NC}"
  echo "Verifica que:"
  echo "  - MySQL esté corriendo"
  echo "  - Las credenciales en wp-config.php sean correctas"
  exit 1
fi
echo -e "${GREEN}MySQL connection OK ✅${NC}"

# Verificar si la base de datos existe
printf '\nChecking if database exists...\n'
if ! $MYSQL_CMD -e "SHOW DATABASES LIKE '$DBNAME';" 2>/dev/null | grep -q "$DBNAME"; then
  echo -e "${RED}ERROR: La base de datos '$DBNAME' no existe ❌${NC}"
  exit 1
fi
echo -e "${GREEN}Database found ✅${NC}"

USERS_TABLE="${TABLE_PREFIX}users"

# Verificar si el usuario existe
printf '\nChecking if user ID=%s exists...\n' "$USER_ID"
USER_EXISTS=$($MYSQL_CMD -N -e "SELECT ID FROM $DBNAME.$USERS_TABLE WHERE ID=$USER_ID;" 2>/dev/null || true)

if [ -z "$USER_EXISTS" ]; then
  echo -e "${RED}ERROR: El usuario con ID=$USER_ID no existe ❌${NC}"
  echo ""
  echo "Usuarios disponibles:"
  $MYSQL_CMD -e "SELECT ID, user_login, user_email FROM $DBNAME.$USERS_TABLE;" 2>/dev/null
  exit 1
fi
echo -e "${GREEN}User found ✅${NC}"

# Mostrar datos actuales del usuario
printf '\nDatos actuales del usuario:\n'
echo -e "${YELLOW}"
$MYSQL_CMD -e "SELECT ID, user_login, user_email, user_nicename FROM $DBNAME.$USERS_TABLE WHERE ID=$USER_ID;" 2>/dev/null
echo -e "${NC}"

# Confirmar antes de proceder
echo -e "${RED}¡ATENCIÓN! Esta acción modificará el usuario.${NC}"
echo ""
echo "Nuevos datos:"
echo -e "  user_login:    ${GREEN}$DEFAULT_LOGIN${NC}"
echo -e "  user_pass:     ${GREEN}$DEFAULT_PASS${NC} (MD5)"
echo -e "  user_nicename: ${GREEN}$DEFAULT_LOGIN${NC}"
echo -e "  user_email:    ${GREEN}$DEFAULT_EMAIL${NC}"
echo ""
read -p "¿Continuar? (s/N): " CONFIRM

if [[ ! "$CONFIRM" =~ ^[sS]$ ]]; then
  echo -e "${YELLOW}Operación cancelada${NC}"
  exit 0
fi

# Ejecutar el UPDATE
printf '\nUpdating user...\n'
if ! $MYSQL_CMD -e "
UPDATE $DBNAME.$USERS_TABLE
SET
  user_login = '$DEFAULT_LOGIN',
  user_pass = MD5('$DEFAULT_PASS'),
  user_nicename = '$DEFAULT_LOGIN',
  user_email = '$DEFAULT_EMAIL'
WHERE ID = $USER_ID;
" 2>/dev/null; then
  echo -e "${RED}ERROR: No se pudo actualizar el usuario ❌${NC}"
  exit 1
fi
echo -e "${GREEN}User updated ✅${NC}"

# Mostrar los nuevos datos
printf '\nNuevos datos del usuario:\n'
echo -e "${GREEN}"
$MYSQL_CMD -e "SELECT ID, user_login, user_email, user_nicename FROM $DBNAME.$USERS_TABLE WHERE ID=$USER_ID;" 2>/dev/null
echo -e "${NC}"

echo ""
echo -e "${GREEN}¡Usuario reseteado correctamente! 🎉${NC}"
echo ""
echo -e "Credenciales de acceso:"
echo -e "  Usuario: ${YELLOW}$DEFAULT_LOGIN${NC}"
echo -e "  Password: ${YELLOW}$DEFAULT_PASS${NC}"
echo ""
echo -e "${RED}⚠️  Recuerda cambiar la contraseña después de iniciar sesión${NC}"
echo ""
