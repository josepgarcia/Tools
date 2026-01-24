#!/bin/bash
# shellcheck disable=SC2155
set -Eeuo pipefail

# Script para detectar contenido mixto (HTTP en sitios HTTPS)
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

check_url() {
    local url="$1"
    info "Escaneando Mixed Content en: $url"

    # Obtener contenido de la página
    local content=$(curl -sL "$url")
    
    # Buscar patrones de http:// que no sean xmlns o similares (aunque en una auditoría de mixed content todo http suele ser sospechoso)
    # Filtramos por extensiones comunes de recursos (js, css, png, jpg, webp, avif, fonts, etc.)
    local mixed=$(echo "$content" | grep -Eo "http://[^\"]+\.(js|css|png|jpg|jpeg|gif|webp|avif|woff|woff2|otf|ttf|svg|mp4|webm)" | sort -u || true)

    if [ -n "$mixed" ]; then
        warning "¡Contenido mixto detectado!"
        echo "$mixed" | while read -r line; do
            echo -e "  ${RED}✗${NC} $line"
        done
    else
        success "No se detectaron recursos HTTP (JS/CSS/Imágenes/Fuentes)."
    fi
}

main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}        Mixed Content Detector${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    if [ $# -eq 0 ]; then
        echo "Uso: tools wp-mixed-content <URL>"
        exit 1
    fi

    local url="$1"
    
    # Validar que la URL empieza por https
    if [[ ! "$url" =~ ^https:// ]]; then
        warning "La URL no empieza por https://. Probablemente no sea necesario escanear mixed content."
    fi

    check_url "$url"
}

main "$@"
