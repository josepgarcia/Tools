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
RESIZE_IMAGES=1
RESIZE_MODE_FROM_ARGS=0

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
  --no-resize         Convierte formato/calidad sin cambiar dimensiones
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
            --no-resize) RESIZE_IMAGES=0; RESIZE_MODE_FROM_ARGS=1 ;;
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
    local files=("${OUTPUT_DIR}"/*.${OUTPUT_EXT})
    shopt -u nullglob nocaseglob

    if [ ${#files[@]} -eq 0 ]; then
        warning "No se encontraron archivos en '${OUTPUT_DIR}/' con extensión ${OUTPUT_EXT} para rotar."
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
    echo -e "${BLUE}¿Qué tipo de imagen deseas procesar?${NC}"
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

# Función para preguntar si se debe cambiar el tamaño
ask_resize_images() {
    echo ""
    read -p "$(echo -e ${BLUE}¿Quieres cambiar el tamaño de las imágenes? [s/N]:${NC} )" resize_confirm

    if [[ "$resize_confirm" =~ ^[sS]$ ]]; then
        RESIZE_IMAGES=1
        success "Se cambiará el tamaño de las imágenes."
    else
        RESIZE_IMAGES=0
        success "Solo se convertirá el formato; se conservarán las dimensiones originales."
    fi
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

# Función para solicitar la altura máxima
ask_max_height() {
    echo ""
    read -p "$(echo -e ${BLUE}Introduce la altura máxima para redimensionar las imágenes [px]:${NC} )" max_height

    if [ -z "$max_height" ]; then
        max_height=$max_width
        success "Altura establecida igual a la anchura: ${max_height}px."
    else
        # Validar que es un número
        if ! [[ "$max_height" =~ ^[0-9]+$ ]]; then
            error "La altura debe ser un número entero positivo."
        fi

        if [ "$max_height" -lt 1 ]; then
            error "La altura debe ser mayor que 0."
        fi
        
        success "Altura establecida en ${max_height}px."
    fi
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
            OUTPUT_DIR="out-jpg"
            ;;
        2)
            OUTPUT_FORMAT="--webp"
            OUTPUT_QUALITY="{quality:${WEBP_QUALITY}}"
            OUTPUT_EXT="webp"
            OUTPUT_DIR="out-webp"
            ;;
        3)
            OUTPUT_FORMAT="--avif"
            OUTPUT_QUALITY="{quality:${AVIF_QUALITY}}"
            OUTPUT_EXT="avif"
            OUTPUT_DIR="out-avif"
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
    if [ $RESIZE_IMAGES -eq 1 ]; then
        echo "  - Cambiar tamaño: sí"
        echo "  - Anchura máxima: ${max_width}px"
        echo "  - Altura máxima: ${max_height}px"
    else
        echo "  - Cambiar tamaño: no"
    fi
    echo "  - Formato de salida: $OUTPUT_EXT"
    echo "  - Directorio de salida: $OUTPUT_DIR/"
    if [ $ARTERO_MODE -eq 1 ]; then
        echo "  - Modo ARTERO: rotar 90º antihorario solo imágenes apaisadas en '$OUTPUT_DIR/'"
    fi
    echo ""

    # Crear directorio de salida si no existe
    mkdir -p "$OUTPUT_DIR"

    if [ $ASSUME_YES -eq 0 ]; then
        read -p "$(echo -e ${YELLOW}¿Deseas continuar con el proceso? [s/N]:${NC} )" confirm
        if [[ ! "$confirm" =~ ^[sS]$ ]]; then
            warning "Operación cancelada por el usuario."
            exit 0
        fi
    else
        info "Confirmación automática (--yes)."
    fi

    if [ $RESIZE_IMAGES -eq 1 ]; then
        info "Iniciando el proceso de redimensionado..."
    else
        info "Iniciando el proceso de conversión..."
    fi
    echo ""

    # Variable para controlar el estado de ejecución
    has_errors=0

    # Detectar la plataforma (para Mac con Apple Silicon)
    PLATFORM_FLAGS=()
    if [[ "$(uname -m)" == "arm64" ]]; then
        info "Detectado Mac con Apple Silicon, usando emulación AMD64..."
        PLATFORM_FLAGS=(--platform linux/amd64)
    fi

    # Tamaño del lote para procesar (evitar problemas de memoria)
    BATCH_SIZE=${BATCH_SIZE:-10}

    # Recoger lista completa de entrada y métricas de entrada
    local all_inputs=()
    shopt -s nullglob nocaseglob
    case "$image_option" in
        1) all_inputs=(*.jpg *.jpeg *.JPG *.JPEG) ;;
        2) all_inputs=(*.png *.PNG) ;;
        3) all_inputs=(*.jpg *.jpeg *.JPG *.JPEG *.png *.PNG) ;;
    esac
    shopt -u nullglob nocaseglob

    for f in "${all_inputs[@]}"; do
        lower_f=$(echo "$f" | tr '[:upper:]' '[:lower:]')
        case "$lower_f" in
            *.png) COUNT_PNG=$((COUNT_PNG+1));;
            *.jpg|*.jpeg) COUNT_JPG=$((COUNT_JPG+1));;
        esac
    done

    for f in "${all_inputs[@]}"; do
        if [ -f "$f" ]; then
            local s
            s=$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f" 2>/dev/null || echo 0)
            INPUT_TOTAL_BYTES=$((INPUT_TOTAL_BYTES + s))
        fi
    done

    # Identificar Imagen
    local SQUOOSH_IMAGE="willh/squoosh-cli:latest"

    # Helper para procesar archivos en lotes
    process_files() {
        # Guardamos IFS actual y lo restauramos al default para evitar problemas con arrays en Bash 3.2
        local OLD_IFS="$IFS"
        IFS=$' \t\n'
        
        local files_to_process=("$@")
        if [ ${#files_to_process[@]} -eq 0 ]; then IFS="$OLD_IFS"; return; fi

        local total_files=${#files_to_process[@]}
        info "Procesando $total_files archivo(s) en lotes de $BATCH_SIZE..."

        for ((i=0; i<total_files; i+=BATCH_SIZE)); do
            local batch=("${files_to_process[@]:i:BATCH_SIZE}")
            local batch_num=$((i/BATCH_SIZE + 1))
            local total_batches=$(((total_files + BATCH_SIZE - 1) / BATCH_SIZE))

            info "  Lote $batch_num de $total_batches (${#batch[@]} archivos)..."

            # Arrays para separar horizontales (resize width) y verticales (resize height)
            local batch_width=()
            local batch_height=()
            local batch_convert=()

            for p in "${batch[@]}"; do
                # 1. Comprobación skip-existing
                local base=$(basename "$p")
                local name="${base%.*}"
                local out="${OUTPUT_DIR}/${name}.${OUTPUT_EXT}"
                if [ $SKIP_EXISTING -eq 1 ] && [ -f "$out" ] && [ "$out" -nt "$p" ]; then
                    info "Saltando (más reciente): $out"
                    continue
                fi

                if [ $RESIZE_IMAGES -eq 0 ]; then
                    batch_convert+=("$p")
                    continue
                fi

                # 2. Detectar orientación con sips
                # Si falla sips, asumimos horizontal (width) por defecto
                local w=$(sips -g pixelWidth "$p" 2>/dev/null | awk '/pixelWidth:/ {print $2}')
                local h=$(sips -g pixelHeight "$p" 2>/dev/null | awk '/pixelHeight:/ {print $2}')

                if [[ -n "$w" && -n "$h" && "$h" -gt "$w" ]]; then
                    # Vertical: redimensionar restringiendo ALTURA
                    batch_height+=("$p")
                else
                    # Horizontal o Cuadrada o fallo detección: redimensionar restringiendo ANCHURA
                    batch_width+=("$p")
                fi
            done

            local batch_has_errors=0

            # Procesar sin redimensionar
            if [ ${#batch_convert[@]} -gt 0 ]; then
                if [ $DRY_RUN -eq 1 ]; then
                    info "[dry-run] Convertir sin cambiar tamaño: ${#batch_convert[@]} archs"
                elif docker run --rm "${PLATFORM_FLAGS[@]}" -v "${PWD}":/data --workdir /data "$SQUOOSH_IMAGE" $OUTPUT_FORMAT "$OUTPUT_QUALITY" -d "$OUTPUT_DIR" "${batch_convert[@]}"; then
                    : # OK
                else
                    warning "  ✗ Fallo en sub-lote de conversión"
                    batch_has_errors=1
                fi
            fi

            # Procesar Horizontales
            if [ ${#batch_width[@]} -gt 0 ]; then
                if [ $DRY_RUN -eq 1 ]; then
                    info "[dry-run] Resize por WIDTH ($max_width px): ${#batch_width[@]} archs"
                elif docker run --rm "${PLATFORM_FLAGS[@]}" -v "${PWD}":/data --workdir /data "$SQUOOSH_IMAGE" $OUTPUT_FORMAT "$OUTPUT_QUALITY" --resize "{width:${max_width}}" -d "$OUTPUT_DIR" "${batch_width[@]}"; then
                    : # OK
                else
                    warning "  ✗ Fallo en sub-lote horizontal"
                    batch_has_errors=1
                fi
            fi

            # Procesar Verticales
            if [ ${#batch_height[@]} -gt 0 ]; then
                if [ $DRY_RUN -eq 1 ]; then
                    info "[dry-run] Resize por HEIGHT ($max_height px): ${#batch_height[@]} archs"
                elif docker run --rm "${PLATFORM_FLAGS[@]}" -v "${PWD}":/data --workdir /data "$SQUOOSH_IMAGE" $OUTPUT_FORMAT "$OUTPUT_QUALITY" --resize "{height:${max_height}}" -d "$OUTPUT_DIR" "${batch_height[@]}"; then
                    : # OK
                else
                    warning "  ✗ Fallo en sub-lote vertical"
                    batch_has_errors=1
                fi
            fi

            if [ ${#batch_convert[@]} -eq 0 ] && [ ${#batch_width[@]} -eq 0 ] && [ ${#batch_height[@]} -eq 0 ]; then
                 success "  ✓ Lote sin cambios (skip-existing)"
            elif [ $batch_has_errors -eq 0 ]; then
                 success "  ✓ Lote $batch_num completado"
            else
                 has_errors=1
            fi
        done
    }

    if [ ${#all_inputs[@]} -gt 0 ]; then
        process_files "${all_inputs[@]}"
    else
        error "No se encontraron archivos para procesar."
    fi

    echo ""
    # Calcular bytes salida
    if [ $DRY_RUN -eq 0 ]; then
        OUTPUT_TOTAL_BYTES=0
        if ls out/* >/dev/null 2>&1; then
            for f in out/*; do
                [ -f "$f" ] || continue
                s=$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f" 2>/dev/null || echo 0)
                OUTPUT_TOTAL_BYTES=$((OUTPUT_TOTAL_BYTES + s))
            done
        fi
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
        if [ $RESIZE_IMAGES -eq 1 ]; then
            success "Las imágenes redimensionadas se encuentran en el directorio '$OUTPUT_DIR/'"
        else
            success "Las imágenes convertidas se encuentran en el directorio '$OUTPUT_DIR/'"
        fi

        # Listar archivos generados
        if [ -d "$OUTPUT_DIR" ]; then
            echo ""
            info "Resumen de archivos generados:"
            file_count=$(ls -1q "$OUTPUT_DIR"/ | wc -l | tr -d ' ')
            total_size=$(du -sh "$OUTPUT_DIR"/ | cut -f1)
            echo "  - Total de archivos: $file_count"
            echo "  - Tamaño total: $total_size"
            echo ""
            info "Resumen detallado:"
            echo "  - JPG procesados: $COUNT_JPG"
            echo "  - PNG procesados: $COUNT_PNG"
            if [ $DRY_RUN -eq 0 ]; then
                in_mb=$(awk -v b=$INPUT_TOTAL_BYTES 'BEGIN{printf "%.2f", b/1048576}')
                out_mb=$(awk 'BEGIN{print 0}')
                if ls "$OUTPUT_DIR"/* >/dev/null 2>&1; then
                    out_mb=$(du -sk "$OUTPUT_DIR"/ | awk '{printf "%.1f", $1/1024}')
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

    # 4. Preguntar si se debe redimensionar
    if [ $RESIZE_MODE_FROM_ARGS -eq 0 ]; then
        ask_resize_images
    fi

    # 4b. Preguntar dimensiones solo si se debe redimensionar
    if [ $RESIZE_IMAGES -eq 1 ]; then
        ask_max_width
        ask_max_height
    fi

    # 5. Corregir orientación EXIF
    fix_orientation

    # 6. Ejecutar Docker
    execute_docker
}

# Ejecutar el script principal
main "$@"
