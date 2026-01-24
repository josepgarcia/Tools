#!/bin/bash
# shellcheck disable=SC2155
set -Eeuo pipefail

# Script para optimizar la base de datos de WordPress usando WP-CLI
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

check_wp_cli() {
    if ! command -v wp &>/dev/null; then
        error "WP-CLI no está instalado. Instálalo desde https://wp-cli.org/"
    fi
}

check_is_wp() {
    if ! wp core is-installed &>/dev/null; then
        error "No se detectó una instalación de WordPress en este directorio."
    fi
}

optimize_db() {
    info "Iniciando optimización de base de datos..."

    # 1. Eliminar revisiones
    info "Eliminando revisiones de posts..."
    local revisions=$(wp post list --post_type='revision' --format=ids)
    if [ -n "$revisions" ]; then
        wp post delete $revisions --force >/dev/null
        success "Revisiones eliminadas."
    else
        info "No se encontraron revisiones."
    fi

    # 2. Eliminar comentarios spam
    info "Eliminando comentarios marcados como spam..."
    local spam_comments=$(wp comment list --status=spam --format=ids)
    if [ -n "$spam_comments" ]; then
        wp comment delete $spam_comments --force >/dev/null
        success "Comentarios spam eliminados."
    else
        info "No hay comentarios spam."
    fi

    # 3. Eliminar comentarios en la papelera
    info "Limpiando papelera de comentarios..."
    wp comment delete $(wp comment list --status=trash --format=ids) --force 2>/dev/null || true

    # 4. Eliminar transientes expirados (y todos los demás)
    info "Limpiando transientes..."
    wp transient delete --all >/dev/null
    success "Transientes eliminados."

    # 5. Optimización de tablas (MySQL Optimize)
    info "Ejecutando OPTIMIZE TABLE en la base de datos..."
    wp db optimize
    success "Tablas optimizadas."

    echo ""
    success "¡WordPress optimizado con éxito!"
}

main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}     WordPress Database Optimizer${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    check_wp_cli
    check_is_wp
    
    read -p "¿Estás seguro de que deseas limpiar y optimizar la base de datos? [s/N]: " confirm
    if [[ ! "$confirm" =~ ^[sS]$ ]]; then
        info "Operación cancelada."
        exit 0
    fi

    optimize_db
}

main
