#!/bin/bash

# wp-db-backup.sh
# Creates a backup of the current WordPress database
# Naming convention: backup_FOLDER_X_COMMENT_TIMESTAMP.sql.gz

###############################################
# COLORS
###############################################
GREEN='\033[0;32m'
BLUE="\033[1;34m"
RED="\033[1;31m"
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

mysqlbin="/opt/homebrew/opt/mysql@8.4/bin/mysql"
mysqldumpbin="/opt/homebrew/opt/mysql@8.4/bin/mysqldump"

# Checking if mysqldump exists, if not try default specific to user
if [ ! -f "$mysqldumpbin" ]; then
    mysqldumpbin="mysqldump"
fi
if [ ! -f "$mysqlbin" ]; then
    mysqlbin="mysql"
fi


echo -e "${BLUE}"
echo "+---------------------+"
echo "|   WP DB Backup      |"
echo "+---------------------+"
echo -e "${NC}"

if [ ! -f "wp-config.php" ]; then
  echo -e "${RED}ERROR: No wp-config.php found.${NC}"
  echo "Execute this script in the WordPress root."
  exit 1
fi

# 1. Read Credentials
extract_define() {
  local key=$1
  local value=$(grep "define.*['\"]$key['\"]" wp-config.php | sed -E "s/.*define\s*\(\s*['\"]$key['\"]\s*,\s*['\"]([^'\"]*)['\"].*/\1/")
  echo "$value"
}

DBNAME=$(extract_define "DB_NAME")
DBUSER=$(extract_define "DB_USER")
DBPASS=$(extract_define "DB_PASSWORD")
DBHOST=$(extract_define "DB_HOST")

if [ -z "$DBNAME" ]; then
    echo -e "${RED}Error reading DB credentials.${NC}"
    exit 1
fi

if [ "$DBHOST" != "localhost" ] && [ -n "$DBHOST" ]; then
  MYSQL_OPTS="-h $DBHOST -u $DBUSER -p$DBPASS"
else
  MYSQL_OPTS="-u $DBUSER -p$DBPASS"
fi

# 2. Folder Name
FOLDER_NAME=$(basename "$(pwd)")

# 3. Calculate X (Autoincrement)
# We look for files matching backup_FOLDER_NAME_*.sql.gz or .sql
MAX_X=0
# Allow matching both compressed and uncompressed for continuity if needed, 
# but primarily we focus on the new pattern.
FILES=( "backup_${FOLDER_NAME}_"*.sql "backup_${FOLDER_NAME}_"*.sql.gz "${FOLDER_NAME}_"*.sql )

for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        # Try to extract number from new pattern backup_FOLDER_X_...
        # Remove prefix backup_FOLDER_
        rest="${file#backup_${FOLDER_NAME}_}"
        # If it didn't match (old format), try removing FOLDER_
        if [ "$rest" == "$file" ]; then
             rest="${file#${FOLDER_NAME}_}"
        fi
        
        # Extract number (digits before next underscore)
        num=$(echo "$rest" | cut -d'_' -f1)
        
        # Check if it is a number
        if [[ "$num" =~ ^[0-9]+$ ]]; then
            if (( num > MAX_X )); then
                MAX_X=$num
            fi
        fi
    fi
done

NEXT_X=$((MAX_X + 1))

# 4. Input Comment
COMMENT=""
if [ -n "$1" ]; then
    COMMENT="_$1"
else
    # If not passed as argument, logic in tools script might have prompted, or we prompt here if empty
    # But usually this script is called by `tools`, so we'll just check if there is an arg
    :
fi

# Sanitize comment (replace spaces with hyphens, remove special chars)
COMMENT=$(echo "$COMMENT" | tr ' ' '-' | tr -cd '[:alnum:]_-')

# 5. Timestamp
TIMESTAMP=$(date +"%Y%m%d%H%M%S")

# 6. Filename
FILENAME="backup_${FOLDER_NAME}_${NEXT_X}${COMMENT}_${TIMESTAMP}.sql.gz"

# 7. Execute Dump
echo -e "Backing up database ${YELLOW}$DBNAME${NC} to ${YELLOW}$FILENAME${NC}..."

$mysqldumpbin $MYSQL_OPTS --add-drop-table "$DBNAME" | gzip > "$FILENAME"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Backup created successfully! ✅${NC}"
else
    echo -e "${RED}Error creating backup ❌${NC}"
    rm -f "$FILENAME" # Cleanup empty file
    exit 1
fi
