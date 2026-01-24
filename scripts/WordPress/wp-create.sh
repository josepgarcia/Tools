#!/bin/bash

set -euo pipefail

SCRIPTPATH=$(dirname "$0")
source $SCRIPTPATH/common.sh

###############################################

if ! [[ $# -eq 1 ]]; then
  echo 'Necesario 1 parámetro, nombre del proyecto'
  exit 1
fi

clear
echo -e "${BLUE}"
echo "+---------------------+"
echo "| WordPress Installer |"
echo "+---------------------+"
echo -e "${NC}"

# Validar que MySQL esté corriendo y se pueda conectar
printf '\nChecking MySQL connection...\n'
if ! check_mysql_connection; then
  echo -e "${RED}ERROR: No se puede conectar a MySQL ❌${NC}"
  echo "Verifica que:"
  echo "  - MySQL esté corriendo"
  echo "  - Las credenciales en common.sh sean correctas"
  echo "  - El usuario tenga permisos suficientes"
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
if ! $mysqlbin -u $DBUSER -p$DBPASS -e "CREATE DATABASE $DBNAME CHARACTER SET utf8 COLLATE utf8_general_ci;" 2>/dev/null; then
  echo -e "${RED}ERROR: No se pudo crear la base de datos ❌${NC}"
  exit 1
fi
echo -e "${GREEN}Database created ✅${NC}"
printf '\n'

mkdir $DIRNAME
cd $DIRNAME

printf '\nWordPress...\n'
echo "Downloading the latest version of Wordpress... "
#curl --remote-name --silent --show-error https://es.wordpress.org/latest-es_ES.zip
curl --remote-name --progress-bar --show-error https://es.wordpress.org/latest-es_ES.zip
## IF ERROR
echo -e "${GREEN}Done! ✅${NC}"
printf '\n'

#tar -zxvf latest.tar.gz
echo "Unzipping"
unzip latest-es_ES.zip
rm latest-es_ES.zip
mv wordpress/* .
rm -rf wordpress
echo -e "${GREEN}Done! ✅${NC}"

printf '\n'
echo "Configuring WordPress... "
cp wp-config-sample.php wp-config.php
#set database details with perl find and replace
### PROVAR ESTOS
perl -pi -e "s/database_name_here/$DBNAME/g" wp-config.php
perl -pi -e "s/username_here/$DBUSER/g" wp-config.php
perl -pi -e "s/password_here/$DBPASS/g" wp-config.php
RAND_DB=$(head -c 4 /dev/urandom | md5sum | cut -c 1-4)
perl -pi -e "s/\'wp_\'/\'wp${RAND_DB}_\'/g" wp-config.php
#sed -i "" "s/database_name_here/$DBNAME/g" wp-config.php
#sed -i "" "s/username_here/$DBUSER/g" wp-config.php
#sed -i "" "s/password_here/$DBPASS/g" wp-config.php
# sed -i "" "s/localhost/localhost/g" wp-config.php

#   Set authentication unique keys and salts in wp-config.php
echo "Setting authentication unique keys and salts..."
# Fetch new salts from the WordPress.org API
SALTS=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)
if [[ -z "$SALTS" ]]; then
  echo -e "${RED}ERROR: Failed to fetch salts from WordPress.org API ❌${NC}"
  exit 1
fi

# Create a temp file
TMP_FILE=$(mktemp)

# Use grep to find the start and end lines of the salt block to replace
START_LINE=$(grep -n "define( 'AUTH_KEY'" wp-config.php | cut -d: -f1)
END_LINE=$(grep -n "define( 'NONCE_SALT'" wp-config.php | cut -d: -f1)

if [[ -z "$START_LINE" || -z "$END_LINE" ]]; then
    echo -e "${RED}ERROR: Could not find salt block placeholder in wp-config.php ❌${NC}"
    exit 1
fi

# Replace the placeholder block with the new salts
head -n $((START_LINE - 1)) wp-config.php > "$TMP_FILE"
echo "$SALTS" >> "$TMP_FILE"
tail -n +$((END_LINE + 1)) wp-config.php >> "$TMP_FILE"

# Overwrite the original file
mv "$TMP_FILE" wp-config.php

echo -e "${GREEN}Done! ✅${NC}"
printf '\n'

echo "Applying folder and file permissions... "
find . -type d -exec chmod 755 {} \;
find . -type f -exec chmod 644 {} \;
echo -e "${GREEN}Done! ✅${NC}"
printf '\n'

echo "Removing default WordPress plugins..."
rm -rf wp-content/plugins/akismet
rm -rf wp-content/plugins/hello.php
echo -e "${GREEN}Done! ✅${NC}"
printf '\n'

echo "Removing default WordPress themes..."
rm -rf wp-content/themes/twentyfifteen
rm -rf wp-content/themes/twentysixteen
rm -rf wp-content/themes/twentyseventeen
rm -rf wp-content/themes/twentynineteen
rm -rf wp-content/themes/twentytwenty
rm -rf wp-content/themes/twentytwentyone
rm -rf wp-content/themes/twentytwentytwo
rm -rf wp-content/themes/twentytwentythree
rm -rf wp-content/themes/twentytwentyfour
#rm -rf wp-content/themes/twentytwentyfive
echo -e "${GREEN}Done! ✅${NC}"
printf '\n'

echo "Removing wp-config-sample.php..."
rm -rf wp-config-sample.php
echo -e "${GREEN}Done! ✅${NC}"
printf '\n'

echo "Copy default modules"
cp -R /Users/josepgarcia/Webs/apache/__WP_THEMES/_INSTALAR/* wp-content/plugins/
echo -e "${GREEN}Done! ✅${NC}"
printf '\n'

printf '\n'
echo -e "${GREEN}Fantastisch! All done 🙌${NC}"
