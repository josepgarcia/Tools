#!/bin/bash
# shellcheck disable=SC2155
set -Eeuo pipefail

# Script para ejecutar auditorías de Lighthouse en lote
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

check_node() {
    if ! command -v node &>/dev/null; then
        error "Node.js no está instalado."
    fi
}

run_lighthouse() {
    local url="$1"
    local output_dir="$2"
    local filename=$(echo "$url" | sed 's/[^a-zA-Z0-9]/_/g')
    
    info "Auditando: $url..."
    
    if npx -y lighthouse "$url" \
        --output=html --output=json \
        --output-path="${output_dir}/${filename}" \
        --chrome-flags="--headless --no-sandbox" >/dev/null 2>&1; then
        success "Reporte generado para $url"
    else
        echo -e "${RED}[FALLO]${NC} Error al auditar $url"
    fi
}

main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}      Lighthouse Batch Runner${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    check_node

    if [ $# -eq 0 ]; then
        echo "Uso: tools wp-lighthouse <URL | archivo_con_urls>"
        exit 1
    fi

    local input="$1"
    local timestamp=$(date +%Y-%m-%d_%H-%M)
    local output_dir="out-lighthouse/${timestamp}"
    mkdir -p "$output_dir"

    if [ -f "$input" ]; then
        info "Procesando URLs desde el archivo: $input"
        while IFS= read -r url || [ -n "$url" ]; do
            [[ -z "$url" || "$url" =~ ^# ]] && continue
            run_lighthouse "$url" "$output_dir"
        done < "$input"
    else
        run_lighthouse "$input" "$output_dir"
    fi

    echo ""
    success "¡Proceso terminado!"
    info "Reportes disponibles en: $output_dir/"
}

main "$@"
