#!/bin/bash

set -euo pipefail

# common.sh
# Shared functions and variables for WordPress scripts

###############################################
# VARIABLES
###############################################

# Variables that depend on $1 (Project Name) if passed.
# Used by wp-create, wp-delete, etc. Keep this safe for scripts that source
# common.sh without positional arguments.
PROJECT_NAME="${1:-}"
if [ -n "$PROJECT_NAME" ]; then
  DIRNAME="wp$PROJECT_NAME"
  DBNAME="wp_$PROJECT_NAME"
else
  DIRNAME=""
  DBNAME=""
fi

# Default Credentials (can be overridden if needed)
DBUSER="${WP_DB_USER:-root}"
DBPASS="${WP_DB_PASS:-root}"
DBHOST="${WP_DB_HOST:-localhost}"

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

###############################################
# FUNCTIONS
###############################################

require_mysql() {
  if [ -z "$mysqlbin" ]; then
    echo -e "${RED}ERROR: 'mysql' binary not found.${NC}"
    echo "Please install MySQL (e.g., 'brew install mysql') or ensure it is in your PATH."
    exit 1
  fi
}

require_mysqldump() {
  if [ -z "$mysqldumpbin" ]; then
    echo -e "${RED}ERROR: 'mysqldump' binary not found.${NC}"
    echo "Please install MySQL client tools or ensure mysqldump is in your PATH."
    exit 1
  fi
}

# Function to validate MySQL connection
check_mysql_connection() {
  require_mysql
  "$mysqlbin" "${MYSQL_OPTS[@]}" -e "SELECT 1;" &>/dev/null
  return $?
}

# Function to check if a database exists
check_database_exists() {
  require_mysql
  local db_name=$1
  local exists
  exists=$("$mysqlbin" "${MYSQL_OPTS[@]}" -N -B -e "SHOW DATABASES LIKE '$db_name';" 2>/dev/null | grep -Fx "$db_name" || true)
  if [ -n "$exists" ]; then
    return 0  # exists
  else
    return 1  # does not exist
  fi
}

validate_project_name() {
  local project_name=$1
  if [[ ! "$project_name" =~ ^[A-Za-z0-9_-]+$ ]]; then
    echo -e "${RED}ERROR: Project name may only contain letters, numbers, underscores, and hyphens.${NC}"
    exit 1
  fi
}

quote_identifier() {
  local identifier=$1
  printf '`%s`' "${identifier//\`/\`\`}"
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

  set_mysql_opts
}

set_mysql_opts() {
  MYSQL_OPTS=(-u "$DBUSER" "-p$DBPASS")
  local host=${DBHOST:-localhost}
  if [ "$host" != "localhost" ] && [ -n "$host" ]; then
    MYSQL_OPTS=(-h "$host" "${MYSQL_OPTS[@]}")
  fi
}

set_mysql_opts
