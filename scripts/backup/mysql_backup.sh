#!/bin/bash
#==============================================================================
# TITLE:            mysql_backup_unified.sh
# DESCRIPTION:      Script unificado para gestión de backups MySQL
# AUTHOR:           Consolidated from multiple scripts
# DATE:             2025-11-20
# VERSION:          1.0
# USAGE:            ./mysql_backup_unified.sh [OPTIONS]
#==============================================================================

#==============================================================================
# CONFIGURACIÓN
#==============================================================================

# Credenciales MySQL
MYSQL_USER="root"
MYSQL_PASSWORD="root"
MYSQL_HOST="localhost"
MYSQL_PORT="3306"

# Rutas de binarios MySQL
#MYSQL_BIN="/opt/homebrew/opt/mysql/bin/mysql"
MYSQL_BIN="/opt/homebrew/opt/mysql@8.4/bin/mysql"
#MYSQLDUMP_BIN="/opt/homebrew/opt/mysql/bin/mysqldump"
MYSQLDUMP_BIN="/opt/homebrew/opt/mysql@8.4/bin/mysqldump"

# Directorio de backups (por defecto)
BACKUP_DIR="./mysql_backups"

# Bases de datos del sistema a ignorar
IGNORE_DB="information_schema|mysql|performance_schema|sys"

# Días para mantener backups (limpieza automática)
KEEP_BACKUPS_FOR=30

# Opciones por defecto
COMPRESS=false
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

#==============================================================================
# COLORES PARA OUTPUT
#==============================================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

#==============================================================================
# FUNCIONES AUXILIARES
#==============================================================================

function hr() {
    printf '=%.0s' {1..80}
    printf "\n"
}

function echo_status() {
    printf '\r'
    printf ' %0.s' {0..100}
    printf '\r'
    printf "$1"'\r'
}

function success_msg() {
    echo -e "${GREEN}✓${NC} $1"
}

function error_msg() {
    echo -e "${RED}✗${NC} $1"
}

function info_msg() {
    echo -e "${BLUE}ℹ${NC} $1"
}

function warning_msg() {
    echo -e "${YELLOW}⚠${NC} $1"
}

function notification() {
    local title="$1"
    local message="$2"
    local sound="$3"

    # Notificación de sistema en macOS
    if command -v osascript &> /dev/null; then
        osascript -e "display notification \"$message\" with title \"$title\" sound name \"$sound\""
    fi
}

#==============================================================================
# FUNCIONES DE VALIDACIÓN
#==============================================================================

function check_mysql_running() {
    info_msg "Verificando que MySQL esté corriendo..."

    if ! pgrep -x mysqld > /dev/null 2>&1; then
        error_msg "MySQL no está corriendo"
        notification "MySQL Backup" "Error: MySQL no está corriendo" "Basso"
        exit 1
    fi

    success_msg "MySQL está corriendo"
}

function check_mysql_connection() {
    info_msg "Verificando conexión a MySQL..."

    if [ -z "$MYSQL_PASSWORD" ]; then
        $MYSQL_BIN -u "$MYSQL_USER" -h "$MYSQL_HOST" -e "SELECT 1;" > /dev/null 2>&1
    else
        $MYSQL_BIN -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -h "$MYSQL_HOST" -e "SELECT 1;" > /dev/null 2>&1
    fi

    if [ $? -ne 0 ]; then
        error_msg "No se pudo conectar a MySQL. Verifica las credenciales."
        notification "MySQL Backup" "Error: No se pudo conectar a MySQL" "Basso"
        exit 1
    fi

    success_msg "Conexión a MySQL establecida"
}

function check_binaries() {
    if [ ! -f "$MYSQL_BIN" ]; then
        error_msg "No se encuentra el binario de mysql en: $MYSQL_BIN"
        exit 1
    fi

    if [ ! -f "$MYSQLDUMP_BIN" ]; then
        error_msg "No se encuentra el binario de mysqldump en: $MYSQLDUMP_BIN"
        exit 1
    fi
}

#==============================================================================
# FUNCIONES DE BASE DE DATOS
#==============================================================================

function get_databases() {
    local show_databases_sql="SHOW DATABASES;"

    if [ -z "$MYSQL_PASSWORD" ]; then
        DATABASES=$($MYSQL_BIN -u "$MYSQL_USER" -h "$MYSQL_HOST" -e "$show_databases_sql" 2>/dev/null | grep -Ev "^(Database|${IGNORE_DB})$" | awk '{print $1}')
    else
        DATABASES=$($MYSQL_BIN -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -h "$MYSQL_HOST" -e "$show_databases_sql" 2>/dev/null | grep -Ev "^(Database|${IGNORE_DB})$" | awk '{print $1}')
    fi

    echo "$DATABASES"
}

function list_databases() {
    hr
    echo -e "${YELLOW}Bases de datos disponibles:${NC}\n"

    local databases=$(get_databases)

    if [ -z "$databases" ]; then
        warning_msg "No se encontraron bases de datos"
        return 1
    fi

    local count=1
    for db in $databases; do
        echo -e "  ${BLUE}$count.${NC} $db"
        ((count++))
    done

    echo ""
    info_msg "Total: $((count-1)) base(s) de datos"
    hr
}

function backup_single_database() {
    local database=$1

    # Verificar que la base de datos existe
    local databases=$(get_databases)
    if ! echo "$databases" | grep -q "^${database}$"; then
        error_msg "La base de datos '$database' no existe"
        return 1
    fi

    # Determinar extensión del archivo
    local extension=".sql"
    if [ "$COMPRESS" = true ]; then
        extension=".sql.gz"
    fi

    local backup_file="$BACKUP_DIR/${database}_${TIMESTAMP}${extension}"

    echo -n "Haciendo backup de: $database ... "

    # Ejecutar mysqldump
    if [ "$COMPRESS" = true ]; then
        if [ -z "$MYSQL_PASSWORD" ]; then
            $MYSQLDUMP_BIN -u "$MYSQL_USER" -h "$MYSQL_HOST" "$database" 2>/dev/null | gzip -9 > "$backup_file"
        else
            $MYSQLDUMP_BIN -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -h "$MYSQL_HOST" "$database" 2>/dev/null | gzip -9 > "$backup_file"
        fi
    else
        if [ -z "$MYSQL_PASSWORD" ]; then
            $MYSQLDUMP_BIN -u "$MYSQL_USER" -h "$MYSQL_HOST" "$database" > "$backup_file" 2>/dev/null
        else
            $MYSQLDUMP_BIN -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -h "$MYSQL_HOST" "$database" > "$backup_file" 2>/dev/null
        fi
    fi

    # Verificar si el backup fue exitoso
    if [ $? -eq 0 ] && [ -s "$backup_file" ]; then
        local size=$(du -h "$backup_file" | cut -f1)
        echo -e "${GREEN}OK${NC} (Tamaño: $size)"
        success_msg "Backup guardado en: $backup_file"
        return 0
    else
        echo -e "${RED}FALLÓ${NC}"
        rm -f "$backup_file"
        return 1
    fi
}

function backup_all_databases() {
    hr
    echo -e "${YELLOW}=== Iniciando Backup de Todas las Bases de Datos ===${NC}"
    echo "Directorio: $BACKUP_DIR"
    echo "Timestamp: $TIMESTAMP"
    if [ "$COMPRESS" = true ]; then
        echo "Compresión: Activada (gzip)"
    fi
    echo ""

    # Crear directorio si no existe
    mkdir -p "$BACKUP_DIR"

    local databases=$(get_databases)

    if [ -z "$databases" ]; then
        error_msg "No se encontraron bases de datos para respaldar"
        notification "MySQL Backup" "Error: No se encontraron bases de datos" "Basso"
        return 1
    fi

    local total=$(echo "$databases" | wc -w | xargs)
    local success=0
    local failed=0

    info_msg "Total de bases de datos a respaldar: $total"
    echo ""

    for db in $databases; do
        if backup_single_database "$db"; then
            ((success++))
        else
            ((failed++))
        fi
    done

    echo ""
    hr
    echo -e "${YELLOW}=== Resumen ===${NC}"
    echo -e "Backups exitosos: ${GREEN}$success${NC}"
    echo -e "Backups fallidos: ${RED}$failed${NC}"
    echo "Directorio: $BACKUP_DIR"
    hr

    if [ $failed -eq 0 ]; then
        success_msg "¡Todos los backups se completaron exitosamente!"
        notification "MySQL Backup" "✓ $success bases de datos respaldadas correctamente" "Glass"
    else
        warning_msg "Se completaron $success backups, $failed fallaron"
        notification "MySQL Backup" "⚠ $success exitosos, $failed fallidos" "Basso"
    fi
}

function restore_database() {
    local database=$1

    # Buscar el backup más reciente
    local backup_file=""

    if [ "$COMPRESS" = true ]; then
        backup_file=$(ls -t "$BACKUP_DIR/${database}"_*.sql.gz 2>/dev/null | head -1)
    else
        backup_file=$(ls -t "$BACKUP_DIR/${database}"_*.sql 2>/dev/null | head -1)
    fi

    if [ -z "$backup_file" ]; then
        error_msg "No se encontró backup para la base de datos '$database'"
        return 1
    fi

    info_msg "Restaurando desde: $backup_file"

    # Crear la base de datos si no existe
    echo -n "Creando base de datos si no existe ... "
    if [ -z "$MYSQL_PASSWORD" ]; then
        $MYSQL_BIN -u "$MYSQL_USER" -h "$MYSQL_HOST" -e "CREATE DATABASE IF NOT EXISTS \`$database\`;" 2>/dev/null
    else
        $MYSQL_BIN -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -h "$MYSQL_HOST" -e "CREATE DATABASE IF NOT EXISTS \`$database\`;" 2>/dev/null
    fi
    echo -e "${GREEN}OK${NC}"

    # Restaurar el backup
    echo -n "Restaurando datos ... "

    if [[ "$backup_file" == *.gz ]]; then
        if [ -z "$MYSQL_PASSWORD" ]; then
            gunzip < "$backup_file" | $MYSQL_BIN -u "$MYSQL_USER" -h "$MYSQL_HOST" "$database" 2>/dev/null
        else
            gunzip < "$backup_file" | $MYSQL_BIN -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -h "$MYSQL_HOST" "$database" 2>/dev/null
        fi
    else
        if [ -z "$MYSQL_PASSWORD" ]; then
            $MYSQL_BIN -u "$MYSQL_USER" -h "$MYSQL_HOST" "$database" < "$backup_file" 2>/dev/null
        else
            $MYSQL_BIN -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -h "$MYSQL_HOST" "$database" < "$backup_file" 2>/dev/null
        fi
    fi

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}OK${NC}"
        success_msg "Base de datos '$database' restaurada exitosamente"
        notification "MySQL Backup" "✓ Base de datos '$database' restaurada" "Glass"
        return 0
    else
        echo -e "${RED}FALLÓ${NC}"
        error_msg "Error al restaurar la base de datos '$database'"
        notification "MySQL Backup" "✗ Error al restaurar '$database'" "Basso"
        return 1
    fi
}

function clean_old_backups() {
    local days=$1

    if [ -z "$days" ]; then
        days=$KEEP_BACKUPS_FOR
    fi

    info_msg "Buscando backups anteriores a $days días..."

    local old_files=$(find "$BACKUP_DIR" -type f \( -name "*.sql" -o -name "*.sql.gz" \) -mtime +$days 2>/dev/null)

    if [ -z "$old_files" ]; then
        info_msg "No se encontraron backups antiguos para eliminar"
        return 0
    fi

    local count=$(echo "$old_files" | wc -l | xargs)
    echo -e "${YELLOW}Se encontraron $count archivo(s) para eliminar:${NC}"
    echo "$old_files"
    echo ""

    read -p "¿Deseas eliminar estos archivos? (s/N): " confirm
    if [[ "$confirm" =~ ^[Ss]$ ]]; then
        echo "$old_files" | xargs rm -f
        success_msg "$count archivo(s) eliminado(s)"
        notification "MySQL Backup" "✓ $count backups antiguos eliminados" "Glass"
    else
        info_msg "Operación cancelada"
    fi
}

#==============================================================================
# AYUDA
#==============================================================================

function show_help() {
    echo -e "${YELLOW}MySQL Backup Manager v1.0${NC}"
    echo ""
    echo -e "${BLUE}USO:${NC}"
    echo "    $0 [OPCIONES]"
    echo ""
    echo -e "${BLUE}OPCIONES:${NC}"
    echo -e "    ${GREEN}-h, --help${NC}              Mostrar esta ayuda"
    echo -e "    ${GREEN}-l, --list${NC}              Listar todas las bases de datos disponibles"
    echo -e "    ${GREEN}-d, --database${NC} <nombre> Hacer backup de una base de datos específica"
    echo -e "    ${GREEN}-a, --all${NC}               Hacer backup de todas las bases de datos"
    echo -e "    ${GREEN}-c, --compress${NC}          Comprimir backups con gzip"
    echo -e "    ${GREEN}-r, --restore${NC} <nombre>  Restaurar una base de datos desde backup"
    echo -e "    ${GREEN}-o, --output${NC} <dir>      Directorio de salida (defecto: $BACKUP_DIR)"
    echo -e "    ${GREEN}--clean${NC} <días>          Eliminar backups más antiguos de N días"
    echo ""
    echo -e "${BLUE}EJEMPLOS:${NC}"
    echo "    # Mostrar ayuda"
    echo "    tools mysql-backup -h"
    echo "    # Listar bases de datos"
    echo "    tools mysql-backup  -l"
    echo "    # Backup de una base de datos"
    echo "    tools mysql-backup  -d wordpress"
    echo "    # Backup de una base de datos con compresión"
    echo "    tools mysql-backup  -d wordpress -c"
    echo "    # Backup de todas las bases de datos"
    echo "    tools mysql-backup  -a"
    echo "    # Backup de todas con compresión"
    echo "    tools mysql-backup  -a -c"
    echo "    # Backup con directorio personalizado"
    echo "    tools mysql-backup  -a -o /tmp/backups"
    echo "    # Restaurar una base de datos"
    echo "    tools mysql-backup  -r wordpress"
    echo "    # Limpiar backups antiguos (30 días)"
    echo "    tools mysql-backup  --clean 30"
    #echo -e "${BLUE}CONFIGURACIÓN:${NC}"
    #echo "    Usuario MySQL: $MYSQL_USER"
    #echo "    Host: $MYSQL_HOST"
    #echo "    Puerto: $MYSQL_PORT"
    #echo "    Directorio backups: $BACKUP_DIR"
    #echo ""
    #echo -e "${YELLOW}NOTA:${NC} Las bases de datos del sistema (information_schema, mysql,"
    #echo "      performance_schema, sys) son excluidas automáticamente."
    echo ""
}

#==============================================================================
# PROCESAMIENTO DE PARÁMETROS
#==============================================================================

# Si no hay parámetros, mostrar ayuda
if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

# Variables para opciones
ACTION=""
DATABASE=""
CLEAN_DAYS=""

# Procesar parámetros
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -l|--list)
            ACTION="list"
            shift
            ;;
        -d|--database)
            ACTION="backup_single"
            DATABASE="$2"
            shift 2
            ;;
        -a|--all)
            ACTION="backup_all"
            shift
            ;;
        -c|--compress)
            COMPRESS=true
            shift
            ;;
        -r|--restore)
            ACTION="restore"
            DATABASE="$2"
            shift 2
            ;;
        -o|--output)
            BACKUP_DIR="$2"
            shift 2
            ;;
        --clean)
            ACTION="clean"
            CLEAN_DAYS="$2"
            shift 2
            ;;
        *)
            error_msg "Opción desconocida: $1"
            echo "Use -h o --help para ver la ayuda"
            exit 1
            ;;
    esac
done

#==============================================================================
# EJECUCIÓN PRINCIPAL
#==============================================================================

# Validaciones previas (excepto para help y clean)
if [[ "$ACTION" != "clean" ]]; then
    check_binaries
    check_mysql_running
    check_mysql_connection
fi

# Crear directorio de backups si no existe
mkdir -p "$BACKUP_DIR"

# Ejecutar acción solicitada
case $ACTION in
    list)
        list_databases
        ;;
    backup_single)
        if [ -z "$DATABASE" ]; then
            error_msg "Debe especificar el nombre de la base de datos"
            exit 1
        fi
        hr
        info_msg "Iniciando backup de: $DATABASE"
        if [ "$COMPRESS" = true ]; then
            info_msg "Compresión: Activada"
        fi
        echo ""
        mkdir -p "$BACKUP_DIR"
        if backup_single_database "$DATABASE"; then
            notification "MySQL Backup" "✓ Backup de '$DATABASE' completado" "Glass"
            exit 0
        else
            notification "MySQL Backup" "✗ Error en backup de '$DATABASE'" "Basso"
            exit 1
        fi
        ;;
    backup_all)
        backup_all_databases
        ;;
    restore)
        if [ -z "$DATABASE" ]; then
            error_msg "Debe especificar el nombre de la base de datos"
            exit 1
        fi
        hr
        restore_database "$DATABASE"
        hr
        ;;
    clean)
        if [ -z "$CLEAN_DAYS" ]; then
            error_msg "Debe especificar el número de días"
            exit 1
        fi
        hr
        clean_old_backups "$CLEAN_DAYS"
        hr
        ;;
    *)
        error_msg "No se especificó ninguna acción válida"
        echo "Use -h o --help para ver la ayuda"
        exit 1
        ;;
esac

exit 0
