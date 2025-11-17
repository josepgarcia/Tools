#!/bin/bash

SCRIPTPATH=$(dirname "$0")
source $SCRIPTPATH/config.file

###############################################

if ! [[ $# -eq 1 ]]; then
  echo 'Necesario 1 parámetro, nombre del plugin' 
  exit 1
fi

clear
echo -e "${BLUE}"
echo "+---------------------+"
echo "| WP plugin           |"
echo "+---------------------+"
echo -e "${NC}"

FILENAME="$1.php"
FILENAME=$( echo $FILENAME | tr '[:upper:]' '[:lower:]' )

echo "Creating plugin: $FILENAME ..."
cat <<EOF > $FILENAME
<?php
/*
Plugin Name: $1
Plugin URI: https://josepgarcia.com
Description: 
Version: 0.1 
*/
EOF

echo -e "${GREEN}Done! ✅${NC}"
printf '\n'
