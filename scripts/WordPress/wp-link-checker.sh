#!/bin/bash
# shellcheck disable=SC2155
set -Eeuo pipefail

# Script para detectar enlaces rotos (404) usando wget
# Autor: Antigravity para Josep Garcia
# Fecha: 24 de enero de 2026

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
warning() { echo -e "${YELLOW}[AVISO]${NC} $1"; }

check_wget() {
    if ! command -v wget &>/dev/null; then
        error "wget no está instalado. Instálalo con 'brew install wget'."
    fi
}

check_links() {
    local url="$1"
    local log_file="out-links_$(date +%Y%m%d_%H%M%S).log"
    
    info "Escanendo enlaces rotos en: $url"
    info "Esto puede tardar dependiendo del tamaño del sitio. Guardando log en $log_file"

    # wget --spider: no descarga archivos, solo comprueba enlaces
    # -r: recursivo
    # -nd: no crear directorios
    # -nv: no verboso (pero guarda errores)
    # -o: log file
    # -l 2: profundidad limitada a 2 para no ser infinito (ajustable)
    if wget --spider -r -l 2 -nd -nv -H -o "$log_file" "$url"; then
        success "Escaneo completado."
    else
        warning "Se encontraron algunos problemas durante el escaneo."
    fi

    echo ""
    info "Resumen de errores (404 / Enlaces Rotos):"
    grep -B 1 "remote file does not exist" "$log_file" || echo "No se encontraron enlaces rotos (404)."
}

main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}        Dead Link Checker CLI${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    check_wget

    if [ $# -eq 0 ]; then
        echo "Uso: tools wp-link-checker <URL>"
        exit 1
    fi

    local url="$1"
    check_links "$url"
}

main "$@"
