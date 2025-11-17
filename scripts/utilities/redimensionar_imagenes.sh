#!/bin/bash
# shellcheck disable=SC2155,SC2086,SC2046
set -Eeuo pipefail
IFS=$'\n\t'

# Script para redimensionar imágenes usando Docker y squoosh-cli
# Autor: Josep Garcia
# Fecha: 17 de octubre de 2025

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Flags, métricas y logging
ARTERO_MODE=0
ASSUME_YES=0
QUIET=0
DRY_RUN=0
SKIP_EXISTING=0

# Calidades configurables desde el script
JPG_QUALITY=80
WEBP_QUALITY=90
AVIF_QUALITY=80

ROTATED_COUNT=0
ROTATED_TIME_MS=0
INPUT_TOTAL_BYTES=0
OUTPUT_TOTAL_BYTES=0
COUNT_JPG=0
COUNT_PNG=0

LOG_FILE="out/process.log"
timestamp() { date '+%Y-%m-%d %H:%M:%S'; }
log_line() {
    local line="$1"
    mkdir -p out
    echo "$(timestamp) | $line" >> "$LOG_FILE"
}

# Parseo simple de argumentos
print_help() {
    cat <<EOF
Uso: $(basename "$0") [opciones]

Opciones:
  -h, --help          Muestra esta ayuda
  -artero             Rota 90º antihorario SOLO imágenes apaisadas en 'out/'
  --yes               No preguntar confirmación interactiva
  --quiet             Salida mínima (mantiene registro en out/process.log)
  --dry-run           No ejecuta, solo muestra acciones planificadas
  --skip-existing     Omite si el archivo de salida es más nuevo que el de entrada
  --jpg-quality=NN    Calidad JPEG (0-100), defecto ${JPG_QUALITY}
  --webp-quality=NN   Calidad WebP (0-100), defecto ${WEBP_QUALITY}
  --avif-quality=NN   Calidad AVIF (0-100), defecto ${AVIF_QUALITY}

Nota: rotación para WEBP/AVIF requiere ImageMagick reciente (magick/mogrify).
EOF
}

parse_args() {
    for arg in "$@"; do
        case "$arg" in
            -artero) ARTERO_MODE=1 ;;
            --yes) ASSUME_YES=1 ;;
            --quiet) QUIET=1 ;;
            --dry-run) DRY_RUN=1 ;;
            --skip-existing) SKIP_EXISTING=1 ;;
            --jpg-quality=*) JPG_QUALITY="${arg#*=}" ;;
            --webp-quality=*) WEBP_QUALITY="${arg#*=}" ;;
            --avif-quality=*) AVIF_QUALITY="${arg#*=}" ;;
            -h|--help) print_help; exit 0 ;;
            *) ;;
        esac
    done

    # Validaciones de calidad
    for pair in "JPG_QUALITY" "WEBP_QUALITY" "AVIF_QUALITY"; do
        val=$(eval echo "\${$pair}")
        if ! [[ "$val" =~ ^[0-9]+$ ]] || [ "$val" -lt 0 ] || [ "$val" -gt 100 ]; then
            error "Valor inválido para $pair: '$val' (debe ser 0-100)"
        fi
    done
}

# Función para mostrar mensajes de error
error() {
    local msg="$1"
    [ $QUIET -eq 0 ] && echo -e "${RED}[ERROR]${NC} $msg" >&2 || true
    log_line "ERROR $msg"
    exit 1
}

# Función para mostrar mensajes de información
info() {
    local msg="$1"
    [ $QUIET -eq 0 ] && echo -e "${BLUE}[INFO]${NC} $msg" || true
    log_line "INFO  $msg"
}

# Función para mostrar mensajes de éxito
success() {
    local msg="$1"
    [ $QUIET -eq 0 ] && echo -e "${GREEN}[OK]${NC} $msg" || true
    log_line "OK    $msg"
}

# Función para mostrar mensajes de advertencia
warning() {
    local msg="$1"
    [ $QUIET -eq 0 ] && echo -e "${YELLOW}[AVISO]${NC} $msg" || true
    log_line "WARN  $msg"
}

# Comprobar si Docker está corriendo
check_docker() {
    info "Comprobando si Docker está corriendo..."

    if ! command -v docker &> /dev/null; then
        error "Docker no está instalado en el sistema."
    fi

    if ! docker info &> /dev/null; then
        error "Docker no está corriendo. Por favor, inicia Docker Desktop y vuelve a intentarlo."
    fi

    success "Docker está corriendo correctamente."
}

# Función para auto-rotar imágenes según EXIF
fix_orientation() {
    info "Corrigiendo orientación EXIF de las imágenes..."

    local count=0
    local rotated=0
    shopt -s nullglob nocaseglob
    local all_images=(*.jpg *.jpeg *.JPG *.JPEG)
    shopt -u nullglob nocaseglob

    if [ ${#all_images[@]} -eq 0 ]; then
        return
    fi

    for img in "${all_images[@]}"; do
        # Obtener la orientación EXIF actual
        local orientation=$(sips -g pixelHeight -g pixelWidth -g orientation "$img" 2>/dev/null | grep "orientation:" | awk '{print $2}')

        if [ -n "$orientation" ] && [ "$orientation" != "1" ]; then
            # Orientation 1 = Normal, otros valores necesitan rotación
            # sips -r auto rota automáticamente según EXIF y resetea la orientación a 1
            if [ $DRY_RUN -eq 1 ]; then
                info "[dry-run] Autorotaría: $img"
            elif sips -r "$img" &>/dev/null; then
                ((rotated++))
            fi
        fi
        ((count++))
    done

    if [ $rotated -gt 0 ]; then
        success "Orientación corregida en $rotated de $count imagen(es)."
    else
        info "Ninguna imagen necesita corrección de orientación."
    fi
}

# Rotar salidas 90º antihorario SOLO si son apaisadas (ancho > alto)
rotate_artero_outputs() {
    info "Aplicando rotación 90º antihorario a las imágenes finales (solo apaisadas)..."

    shopt -s nullglob nocaseglob
    local files=(out/*.${OUTPUT_EXT})
    shopt -u nullglob nocaseglob

    if [ ${#files[@]} -eq 0 ]; then
        warning "No se encontraron archivos en 'out/' con extensión ${OUTPUT_EXT} para rotar."
        return
    fi

    local rotated_ok=0

    if [[ "$OUTPUT_EXT" == "jpg" || "$OUTPUT_EXT" == "jpeg" || "$OUTPUT_EXT" == "png" ]]; then
        for f in "${files[@]}"; do
            local w=$(sips -g pixelWidth "$f" 2>/dev/null | awk '/pixelWidth:/ {print $2}')
            local h=$(sips -g pixelHeight "$f" 2>/dev/null | awk '/pixelHeight:/ {print $2}')
            if [[ -n "$w" && -n "$h" && "$w" -gt "$h" ]]; then
                if sips --rotate 270 "$f" >/dev/null 2>&1; then
                    rotated_ok=1
                else
                    warning "Fallo al rotar: $f"
                fi
            fi
        done
    else
        if command -v magick >/dev/null 2>&1; then
            for f in "${files[@]}"; do
                local wh=$(magick identify -format "%w %h" "$f" 2>/dev/null)
                local w=$(echo "$wh" | awk '{print $1}')
                local h=$(echo "$wh" | awk '{print $2}')
                if [[ -n "$w" && -n "$h" && "$w" -gt "$h" ]]; then
                    local tmp="$f.tmp"
                    if magick "$f" -rotate -90 "$tmp" >/dev/null 2>&1 && mv "$tmp" "$f"; then
                        rotated_ok=1
                    else
                        rm -f "$tmp" 2>/dev/null || true
                        warning "Fallo al rotar: $f"
                    fi
                fi
            done
        elif command -v mogrify >/dev/null 2>&1; then
            for f in "${files[@]}"; do
                local wh=$(identify -format "%w %h" "$f" 2>/dev/null)
                local w=$(echo "$wh" | awk '{print $1}')
                local h=$(echo "$wh" | awk '{print $2}')
                if [[ -n "$w" && -n "$h" && "$w" -gt "$h" ]]; then
                    if mogrify -rotate -90 "$f" >/dev/null 2>&1; then
                        rotated_ok=1
                    else
                        warning "Fallo al rotar: $f"
                    fi
                fi
            done
        else
            warning "No se encontró ImageMagick (magick/mogrify) para rotar ${OUTPUT_EXT}. Omite rotación."
        fi
    fi

    if [ $rotated_ok -eq 1 ]; then
        success "Rotación antihoraria aplicada a imágenes apaisadas."
    fi
}

# Función para solicitar el tipo de imagen
ask_image_type() {
    echo ""
    echo -e "${BLUE}¿Qué tipo de imagen deseas redimensionar?${NC}"
    echo "  1) JPG/JPEG"
    echo "  2) PNG"
    echo "  3) Ambos (JPG y PNG)"
    echo ""
    read -p "Selecciona una opción [1-3]: " image_option

    case $image_option in
        1)
            IMAGE_EXTENSION="jpg"
            IMAGE_PATTERN="*.jpg"
            ;;
        2)
            IMAGE_EXTENSION="png"
            IMAGE_PATTERN="*.png"
            ;;
        3)
            IMAGE_EXTENSION="jpg,png"
            IMAGE_PATTERN="*.{jpg,png}"
            ;;
        *)
            error "Opción no válida. Debe ser 1, 2 o 3."
            ;;
    esac

    # Verificar que existen archivos del tipo seleccionado
    shopt -s nullglob
    if [ "$image_option" == "3" ]; then
        files=(*.jpg *.jpeg *.JPG *.JPEG *.png *.PNG)
    elif [ "$image_option" == "1" ]; then
        files=(*.jpg *.jpeg *.JPG *.JPEG)
    else
        files=(*.png *.PNG)
    fi
    shopt -u nullglob

    if [ ${#files[@]} -eq 0 ]; then
        error "No se encontraron archivos de tipo $IMAGE_EXTENSION en el directorio actual."
    fi

    success "Se encontraron ${#files[@]} archivo(s) para procesar."
}

# Función para solicitar la anchura máxima
ask_max_width() {
    echo ""
    read -p "$(echo -e ${BLUE}Introduce la anchura máxima para redimensionar las imágenes [px]:${NC} )" max_width

    # Validar que es un número
    if ! [[ "$max_width" =~ ^[0-9]+$ ]]; then
        error "La anchura debe ser un número entero positivo."
    fi

    if [ "$max_width" -lt 1 ]; then
        error "La anchura debe ser mayor que 0."
    fi

    success "Anchura establecida en ${max_width}px."
}

# Función para solicitar el tipo de salida
ask_output_type() {
    echo ""
    echo -e "${BLUE}¿Qué formato de salida deseas?${NC}"
    echo "  1) JPG (MozJPEG)"
    echo "  2) WebP"
    echo "  3) AVIF"
    echo ""
    read -p "Selecciona una opción [1-3]: " output_option

    case $output_option in
        1)
            OUTPUT_FORMAT="--mozjpeg"
            OUTPUT_QUALITY="{quality:${JPG_QUALITY}}"
            OUTPUT_EXT="jpg"
            ;;
        2)
            OUTPUT_FORMAT="--webp"
            OUTPUT_QUALITY="{quality:${WEBP_QUALITY}}"
            OUTPUT_EXT="webp"
            ;;
        3)
            OUTPUT_FORMAT="--avif"
            OUTPUT_QUALITY="{quality:${AVIF_QUALITY}}"
            OUTPUT_EXT="avif"
            ;;
        *)
            error "Opción no válida. Debe ser 1, 2 o 3."
            ;;
    esac

    success "Formato de salida: $OUTPUT_EXT"
}

# Función para ejecutar el comando Docker
execute_docker() {
    echo ""
    info "Configuración seleccionada:"
    echo "  - Tipo de imagen entrada: $IMAGE_EXTENSION"
    echo "  - Anchura máxima: ${max_width}px"
    echo "  - Formato de salida: $OUTPUT_EXT"
    if [ $ARTERO_MODE -eq 1 ]; then
        echo "  - Modo ARTERO: rotar 90º antihorario solo imágenes apaisadas en 'out/'"
    fi
    echo ""

    # Crear directorio de salida si no existe
    mkdir -p out

    if [ $ASSUME_YES -eq 0 ]; then
        read -p "$(echo -e ${YELLOW}¿Deseas continuar con el proceso? [s/N]:${NC} )" confirm
        if [[ ! "$confirm" =~ ^[sS]$ ]]; then
            warning "Operación cancelada por el usuario."
            exit 0
        fi
    else
        info "Confirmación automática (--yes)."
    fi

    info "Iniciando el proceso de redimensionado..."
    echo ""

    # Variable para controlar el estado de ejecución
    has_errors=0

    # Detectar la plataforma (para Mac con Apple Silicon)
    PLATFORM_FLAG=""
    if [[ "$(uname -m)" == "arm64" ]]; then
        info "Detectado Mac con Apple Silicon, usando emulación AMD64..."
        PLATFORM_FLAG="--platform linux/amd64"
    fi

    # Tamaño del lote para procesar (evitar problemas de memoria)
    BATCH_SIZE=${BATCH_SIZE:-10}

    # Recoger lista completa de entrada y métricas de entrada
    local all_inputs=()
    if [ "$image_option" == "3" ]; then
        shopt -s nullglob nocaseglob
        all_inputs=(*.jpg *.jpeg *.png *.JPG *.JPEG *.PNG)
        shopt -u nullglob nocaseglob
    elif [ "$image_option" == "1" ]; then
        shopt -s nullglob nocaseglob
        all_inputs=(*.jpg *.jpeg *.JPG *.JPEG)
        shopt -u nullglob nocaseglob
    else
        shopt -s nullglob nocaseglob
        all_inputs=(*.png *.PNG)
        shopt -u nullglob nocaseglob
    fi
    for f in "${all_inputs[@]}"; do
        case "${f,,}" in
            *.png) COUNT_PNG=$((COUNT_PNG+1));;
            *.jpg|*.jpeg) COUNT_JPG=$((COUNT_JPG+1));;
        esac
    done

    for f in "${all_inputs[@]}"; do
        if [ -f "$f" ]; then
            local s=$(stat -f%z "$f" 2>/dev/null || echo 0)
            INPUT_TOTAL_BYTES=$((INPUT_TOTAL_BYTES + s))
        fi
    done

    # Crear un contenedor único de squoosh-cli y usar docker exec para los lotes
    local SQUOOSH_IMAGE="willh/squoosh-cli:latest"
    local CONTAINER_NAME="squoosh_runner_$$"
    if [ $DRY_RUN -eq 0 ]; then
        docker create --rm $PLATFORM_FLAG -v "${PWD}":/data --workdir /data --name "$CONTAINER_NAME" "$SQUOOSH_IMAGE" sh -c "while true; do sleep 3600; done" >/dev/null
        docker start "$CONTAINER_NAME" >/dev/null
    else
        info "[dry-run] Omitiendo creación de contenedor"
    fi
    if [ "$image_option" == "3" ]; then
        # Procesar JPG
        shopt -s nullglob nocaseglob
        jpg_files=(*.jpg *.jpeg)
        shopt -u nullglob nocaseglob

        if [ ${#jpg_files[@]} -gt 0 ]; then
            total_files=${#jpg_files[@]}
            info "Procesando $total_files archivos JPG/JPEG en lotes de $BATCH_SIZE..."

            for ((i=0; i<total_files; i+=BATCH_SIZE)); do
                batch=("${jpg_files[@]:i:BATCH_SIZE}")
                batch_num=$((i/BATCH_SIZE + 1))
                total_batches=$(((total_files + BATCH_SIZE - 1) / BATCH_SIZE))

                info "  Lote $batch_num de $total_batches (${#batch[@]} archivos)..."

                # Filtrar por --skip-existing
                to_process=()
                for p in "${batch[@]}"; do
                    base=$(basename "$p")
                    name="${base%.*}"
                    out="out/${name}.${OUTPUT_EXT}"
                    if [ $SKIP_EXISTING -eq 1 ] && [ -f "$out" ] && [ "$out" -nt "$p" ]; then
                        info "Saltando (más reciente): $out"
                        continue
                    fi
                    to_process+=("$p")
                done
                if [ ${#to_process[@]} -eq 0 ]; then
                    success "  ✓ Lote sin cambios (skip-existing)"
                elif [ $DRY_RUN -eq 1 ]; then
                    info "[dry-run] Procesaría ${#to_process[@]} archivo(s)"
                elif docker exec "$CONTAINER_NAME" squoosh-cli $OUTPUT_FORMAT "$OUTPUT_QUALITY" --resize "{width:${max_width}}" -d "out" "${to_process[@]}"; then
                    success "  ✓ Lote $batch_num completado"
                else
                    warning "  ✗ Error en lote $batch_num"
                    has_errors=1
                fi
            done
        fi

        # Procesar PNG
        shopt -s nullglob nocaseglob
        png_files=(*.png)
        shopt -u nullglob nocaseglob

        if [ ${#png_files[@]} -gt 0 ]; then
            total_files=${#png_files[@]}
            info "Procesando $total_files archivos PNG en lotes de $BATCH_SIZE..."

            for ((i=0; i<total_files; i+=BATCH_SIZE)); do
                batch=("${png_files[@]:i:BATCH_SIZE}")
                batch_num=$((i/BATCH_SIZE + 1))
                total_batches=$(((total_files + BATCH_SIZE - 1) / BATCH_SIZE))

                info "  Lote $batch_num de $total_batches (${#batch[@]} archivos)..."

                # Filtrar por --skip-existing
                to_process=()
                for p in "${batch[@]}"; do
                    base=$(basename "$p")
                    name="${base%.*}"
                    out="out/${name}.${OUTPUT_EXT}"
                    if [ $SKIP_EXISTING -eq 1 ] && [ -f "$out" ] && [ "$out" -nt "$p" ]; then
                        info "Saltando (más reciente): $out"
                        continue
                    fi
                    to_process+=("$p")
                done
                if [ ${#to_process[@]} -eq 0 ]; then
                    success "  ✓ Lote sin cambios (skip-existing)"
                elif [ $DRY_RUN -eq 1 ]; then
                    info "[dry-run] Procesaría ${#to_process[@]} archivo(s)"
                elif docker exec "$CONTAINER_NAME" squoosh-cli $OUTPUT_FORMAT "$OUTPUT_QUALITY" --resize "{width:${max_width}}" -d "out" "${to_process[@]}"; then
                    success "  ✓ Lote $batch_num completado"
                else
                    warning "  ✗ Error en lote $batch_num"
                    has_errors=1
                fi
            done
        fi
    else
        # Obtener lista de archivos según el tipo seleccionado
        shopt -s nullglob nocaseglob
        if [ "$image_option" == "1" ]; then
            input_files=(*.jpg *.jpeg)
        else
            input_files=(*.png)
        fi
        shopt -u nullglob nocaseglob

        if [ ${#input_files[@]} -gt 0 ]; then
            total_files=${#input_files[@]}
            info "Procesando $total_files archivo(s) en lotes de $BATCH_SIZE..."
            echo ""

            # Procesar en lotes
            for ((i=0; i<total_files; i+=BATCH_SIZE)); do
                batch=("${input_files[@]:i:BATCH_SIZE}")
                batch_num=$((i/BATCH_SIZE + 1))
                total_batches=$(((total_files + BATCH_SIZE - 1) / BATCH_SIZE))

                info "Lote $batch_num de $total_batches (${#batch[@]} archivos)..."

                # Filtrar por --skip-existing
                to_process=()
                for p in "${batch[@]}"; do
                    base=$(basename "$p")
                    name="${base%.*}"
                    out="out/${name}.${OUTPUT_EXT}"
                    if [ $SKIP_EXISTING -eq 1 ] && [ -f "$out" ] && [ "$out" -nt "$p" ]; then
                        info "Saltando (más reciente): $out"
                        continue
                    fi
                    to_process+=("$p")
                done
                if [ ${#to_process[@]} -eq 0 ]; then
                    success "✓ Lote sin cambios (skip-existing)"
                elif [ $DRY_RUN -eq 1 ]; then
                    info "[dry-run] Procesaría ${#to_process[@]} archivo(s)"
                elif docker exec "$CONTAINER_NAME" squoosh-cli $OUTPUT_FORMAT "$OUTPUT_QUALITY" --resize "{width:${max_width}}" -d "out" "${to_process[@]}"; then
                    success "✓ Lote $batch_num completado"
                else
                    warning "✗ Error en lote $batch_num"
                    has_errors=1
                fi
                echo ""
            done
        else
            error "No se encontraron archivos para procesar."
        fi
    fi

    echo ""
    # Cerrar contenedor y calcular bytes salida
    if [ $DRY_RUN -eq 0 ]; then
        OUTPUT_TOTAL_BYTES=0
        if ls out/* >/dev/null 2>&1; then
            for f in out/*; do
                [ -f "$f" ] || continue
                s=$(stat -f%z "$f" 2>/dev/null || echo 0)
                OUTPUT_TOTAL_BYTES=$((OUTPUT_TOTAL_BYTES + s))
            done
        fi
        docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
    fi

    if [ $has_errors -eq 0 ]; then
        # Si se pidió el modo ARTERO, rotar salidas antes del resumen
        if [ $ARTERO_MODE -eq 1 ]; then
            local t0=$(perl -MTime::HiRes=time -e 'printf "%.0f", time()*1000' 2>/dev/null || date +%s000)
            rotate_artero_outputs
            local t1=$(perl -MTime::HiRes=time -e 'printf "%.0f", time()*1000' 2>/dev/null || date +%s000)
            ROTATED_TIME_MS=$((t1 - t0))
        fi
        success "¡Proceso completado con éxito!"
        success "Las imágenes redimensionadas se encuentran en el directorio 'out/'"

        # Listar archivos generados
        if [ -d "out" ]; then
            echo ""
            info "Resumen de archivos generados:"
            file_count=$(ls -1 out/ | wc -l | tr -d ' ')
            total_size=$(du -sh out/ | cut -f1)
            echo "  - Total de archivos: $file_count"
            echo "  - Tamaño total: $total_size"
            echo ""
            info "Resumen detallado:"
            echo "  - JPG procesados: $COUNT_JPG"
            echo "  - PNG procesados: $COUNT_PNG"
            if [ $DRY_RUN -eq 0 ]; then
                in_mb=$(awk -v b=$INPUT_TOTAL_BYTES 'BEGIN{printf "%.2f", b/1048576}')
                out_mb=$(awk 'BEGIN{print 0}')
                if ls out/* >/dev/null 2>&1; then
                    out_mb=$(du -sk out/ | awk '{printf $1/1024}')
                fi
                saved=$(awk -v a=$in_mb -v b=$out_mb 'BEGIN{d=a-b; if(d<0)d=0; printf "%.2f", d}')
                echo "  - Tamaño entrada aprox: ${in_mb}MB"
                echo "  - Tamaño salida aprox:  ${out_mb}MB"
                echo "  - Ahorro aprox:         ${saved}MB"
            fi
            if [ $ARTERO_MODE -eq 1 ]; then
                echo "  - Rotados (-artero):    $ROTATED_COUNT archivo(s) en ${ROTATED_TIME_MS}ms"
            fi
        fi
    else
        error "Hubo errores durante el proceso de redimensionado. Revisa los mensajes anteriores."
    fi
}

# Script principal
main() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Redimensionador de Imágenes (Docker)${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""

    # 0. Parsear argumentos
    parse_args "$@"

    # 1. Comprobar Docker
    check_docker

    # 2. Preguntar tipo de imagen
    ask_image_type

    # 3. Preguntar tipo de salida
    ask_output_type

    # 4. Preguntar anchura máxima
    ask_max_width

    # 5. Corregir orientación EXIF
    fix_orientation

    # 6. Ejecutar Docker
    execute_docker
}

# Ejecutar el script principal
main "$@"
