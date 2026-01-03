#!/bin/bash

set -euo pipefail

# common.sh
# Shared functions and variables for WordPress scripts

###############################################
# VARIABLES
###############################################

# Variables that depend on $1 (Project Name) if passed
# Used by wp-create, wp-delete, etc.
if [ -n "$1" ]; then
  DIRNAME="wp$1"
  DBNAME="wp_$1"
else
  DIRNAME=""
  DBNAME=""
fi

# Default Credentials (can be overridden if needed)
DBUSER="root"
DBPASS="root"

###############################################
# COLORS
###############################################
GREEN='\033[0;32m'
BLUE="\033[1;34m"
RED="\033[1;31m"
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

###############################################
# BINARIES
###############################################
# Helper function to find a binary
find_binary() {
  local binary_name=$1
  if command -v "$binary_name" >/dev/null 2>&1; then
    echo "$binary_name"
  elif [ -f "/opt/homebrew/opt/mysql@8.4/bin/$binary_name" ]; then
    echo "/opt/homebrew/opt/mysql@8.4/bin/$binary_name"
  else
    echo ""
  fi
}

mysqlbin=$(find_binary "mysql")
mysqldumpbin=$(find_binary "mysqldump")

# Validation
if [ -z "$mysqlbin" ]; then
    echo -e "${RED}ERROR: 'mysql' binary not found.${NC}"
    echo "Please install MySQL (e.g., 'brew install mysql') or ensure it is in your PATH."
    exit 1
fi
if [ -z "$mysqldumpbin" ]; then
    # Warning only, as some scripts might not need mysqldump
    :
fi

###############################################
# FUNCTIONS
###############################################

# Function to validate MySQL connection
check_mysql_connection() {
  $mysqlbin -u $DBUSER -p$DBPASS -e '\q' &>/dev/null
  return $?
}

# Function to check if a database exists
check_database_exists() {
  local db_name=$1
  local exists=$($mysqlbin -u $DBUSER -p$DBPASS -e "SHOW DATABASES LIKE '$db_name';" 2>/dev/null | grep "$db_name")
  if [ ! -z "$exists" ]; then
    return 0  # exists
  else
    return 1  # does not exist
  fi
}

# Function to extract a define value from wp-config.php
# Usage: extract_wp_config_define "DB_NAME"
extract_wp_config_define() {
  local key=$1
  if [ ! -f "wp-config.php" ]; then
    echo ""
    return
  fi
  local value=$(grep "define.*['\"]$key['\"]" wp-config.php | sed -E "s/.*define\s*\(\s*['\"]$key['\"]\s*,\s*['\"]([^'\"]*)['\"].*/\1/")
  echo "$value"
}

# Function to get DB credentials from wp-config.php
# Sets global variables: DBNAME, DBUSER, DBPASS, DBHOST
get_db_credentials_from_config() {
  if [ ! -f "wp-config.php" ]; then
    echo -e "${RED}ERROR: No wp-config.php found.${NC}"
    echo "Execute this script in the WordPress root."
    exit 1
  fi

  DBNAME=$(extract_wp_config_define "DB_NAME")
  DBUSER=$(extract_wp_config_define "DB_USER")
  DBPASS=$(extract_wp_config_define "DB_PASSWORD")
  DBHOST=$(extract_wp_config_define "DB_HOST")

  if [ -z "$DBNAME" ]; then
      echo -e "${RED}Error reading DB credentials form wp-config.php.${NC}"
      exit 1
  fi
}

# Get MySQL options based on host
get_mysql_opts() {
   local host=${DBHOST:-localhost}
   if [ "$host" != "localhost" ] && [ -n "$host" ]; then
      echo "-h $host -u $DBUSER -p$DBPASS"
   else
      echo "-u $DBUSER -p$DBPASS"
   fi
}
