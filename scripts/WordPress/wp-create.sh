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
echo "| WordPress Installer |"
echo "+---------------------+"
echo -e "${NC}"

printf '\nCheck MySQL...\n'
$mysqlbin -u $DBUSER -p$DBPASS -e '\q' &>/dev/null
if [ $? -ne 0 ]; then
  echo -e "${RED}MySQL connection error! ❌${NC}"
  exit 1
fi
echo -e "${GREEN}Done! ✅${NC}"

printf '\nCreating DB...'
$mysqlbin -u $DBUSER -p$DBPASS -e "CREATE DATABASE $DBNAME CHARACTER SET utf8 COLLATE utf8_general_ci;" 2>/dev/null
echo -e "${GREEN}Done! ✅${NC}"
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
perl -i -pe '
  BEGIN {
    @chars = ("a" .. "z", "A" .. "Z", 0 .. 9);
    push @chars, split //, "!@#$%^&*()-_ []{}<>~\`+=,.;:/?|";
    sub salt { join "", map $chars[ rand @chars ], 1 .. 64 }
  }
  s/put your unique phrase here/salt()/ge
' wp-config.php

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
