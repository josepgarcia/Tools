#!/bin/bash
# shellcheck disable=SC2155,SC2086,SC2046
set -Eeuo pipefail
IFS=$'\n\t'

# Script para redimensionar imágenes usando sharp-cli (Node.js)
# Autor: Josep Garcia (Adaptado a CLI por Antigravity)
# Fecha: 24 de enero de 2026

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Asegurar que el PATH incluye rutas comunes (necesario para Automator/Acciones Rápidas)
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

# Flags, métricas y logging
ARTERO_MODE=0
ASSUME_YES=0
QUIET=0
DRY_RUN=0
SKIP_EXISTING=0
NO_FOLDER=0
OUTPUT_EXT=""
OUTPUT_EXT=""
max_width=""
max_height=""
image_option=""
FILE_LIST=()

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
  --format=EXT        Formato de salida (jpg, webp, avif)
  --width=PX          Anchura máxima
  --height=PX         Altura máxima
  --no-folder         Guarda en la misma carpeta con sufijo _resized

Nota: rotación para WEBP/AVIF requiere ImageMagick reciente (magick/mogrify).
      Este script requiere Node.js y sharp-cli disponible vía npx.
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
            --format=*) OUTPUT_EXT="${arg#*=}" ;;
            --width=*) max_width="${arg#*=}" ;;
            --height=*) max_height="${arg#*=}" ;;
            --no-folder) NO_FOLDER=1 ;;
            -h|--help) print_help; exit 0 ;;
            -*) ;;
            *) FILE_LIST+=("$arg") ;;
        esac
    done

    # Mapear formato a variables necesarias si se pasó por flag
    if [ -n "$OUTPUT_EXT" ]; then
        case "$OUTPUT_EXT" in
            jpg|jpeg)
                OUTPUT_FORMAT="jpeg"
                OUTPUT_QUALITY="$JPG_QUALITY"
                OUTPUT_EXT="jpg"
                OUTPUT_DIR="out-jpg"
                ;;
            webp)
                OUTPUT_FORMAT="webp"
                OUTPUT_QUALITY="$WEBP_QUALITY"
                OUTPUT_EXT="webp"
                OUTPUT_DIR="out-webp"
                ;;
            avif)
                OUTPUT_FORMAT="avif"
                OUTPUT_QUALITY="$AVIF_QUALITY"
                OUTPUT_EXT="avif"
                OUTPUT_DIR="out-avif"
                ;;
            *) error "Formato no soportado: $OUTPUT_EXT" ;;
        esac
    fi

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
    # Siempre imprimir errores a stderr, incluso en modo QUIET
    echo -e "${RED}[ERROR]${NC} $msg" >&2
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

# Comprobar si Node y npx están disponibles
check_dependencies() {
    info "Comprobando dependencias (Node.js)..."

    if ! command -v node &> /dev/null; then
        error "Node.js no está instalado en el sistema."
    fi

    if ! command -v npx &> /dev/null; then
        error "npx no está disponible. Asegúrate de tener npm instalado."
    fi

    success "Node.js y npx están disponibles."
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
                    ((ROTATED_COUNT++))
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
                        ((ROTATED_COUNT++))
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
                        ((ROTATED_COUNT++))
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

# Función para recoger archivos pasados por argumento
collect_files_from_args() {
    files=("${FILE_LIST[@]}")
    IMAGE_EXTENSION="custom"
    success "Se recibieron ${#files[@]} archivo(s) por argumento."
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
    if [ -z "$max_height" ]; then
        if [ -n "$max_width" ] && [ $ASSUME_YES -eq 1 ]; then
            max_height=$max_width
            success "Altura establecida automáticamente igual a la anchura: ${max_height}px."
        else
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
        fi
    fi
}

# Función para solicitar el tipo de salida
ask_output_type() {
    echo ""
    echo -e "${BLUE}¿Qué formato de salida deseas?${NC}"
    echo "  1) JPG"
    echo "  2) WebP"
    echo "  3) AVIF"
    echo ""
    read -p "Selecciona una opción [1-3]: " output_option

    case $output_option in
        1)
            OUTPUT_FORMAT="jpeg"
            OUTPUT_QUALITY="$JPG_QUALITY"
            OUTPUT_EXT="jpg"
            OUTPUT_DIR="out-jpg"
            ;;
        2)
            OUTPUT_FORMAT="webp"
            OUTPUT_QUALITY="$WEBP_QUALITY"
            OUTPUT_EXT="webp"
            OUTPUT_DIR="out-webp"
            ;;
        3)
            OUTPUT_FORMAT="avif"
            OUTPUT_QUALITY="$AVIF_QUALITY"
            OUTPUT_EXT="avif"
            OUTPUT_DIR="out-avif"
            ;;
        *)
            error "Opción no válida. Debe ser 1, 2 o 3."
            ;;
    esac

    success "Formato de salida: $OUTPUT_EXT"
}

# Función para ejecutar el comando sharp-cli
execute_cli() {
    # Recoger lista completa de archivos antes de configurar directorios
    local all_inputs=()
    if [ "$IMAGE_EXTENSION" == "custom" ]; then
        all_inputs=("${files[@]}")
    else
        shopt -s nullglob nocaseglob
        case "$image_option" in
            1) all_inputs=(*.jpg *.jpeg *.JPG *.JPEG) ;;
            2) all_inputs=(*.png *.PNG) ;;
            3) all_inputs=(*.jpg *.jpeg *.JPG *.JPEG *.png *.PNG) ;;
        esac
        shopt -u nullglob nocaseglob
    fi

    if [ ${#all_inputs[@]} -eq 0 ]; then
        error "No se encontraron archivos para procesar."
    fi

    # Si se pasaron archivos específicos y el primero es una ruta absoluta,
    # ajustar OUTPUT_DIR para que se cree en la misma carpeta que las imágenes.
    if [ $NO_FOLDER -eq 0 ]; then
        if [ "$IMAGE_EXTENSION" == "custom" ] && [[ "${all_inputs[0]}" == /* ]]; then
            local first_dir=$(dirname "${all_inputs[0]}")
            OUTPUT_DIR="${first_dir}/${OUTPUT_DIR}"
        fi
        # Crear directorio de salida si no existe
        mkdir -p "$OUTPUT_DIR"
    fi

    # Notificación de inicio (solo macOS)
    if [ $QUIET -eq 1 ] && command -v osascript &>/dev/null; then
        osascript -e "display notification \"Optimizando ${#all_inputs[@]} imágenes...\" with title \"Sharp Resizer\""
    fi

    if [ $ASSUME_YES -eq 0 ]; then
        read -p "$(echo -e ${YELLOW}¿Deseas continuar con el proceso? [s/N]:${NC} )" confirm
        if [[ ! "$confirm" =~ ^[sS]$ ]]; then
            warning "Operación cancelada por el usuario."
            exit 0
        fi
    else
        info "Confirmación automática (--yes)."
    fi

    info "Iniciando el proceso de redimensionado con sharp-cli..."
    echo ""

    has_errors=0

    # (all_inputs ya está poblada al inicio de execute_cli)

    for f in "${all_inputs[@]}"; do
        lower_f=$(echo "$f" | tr '[:upper:]' '[:lower:]')
        case "$lower_f" in
            *.png) COUNT_PNG=$((COUNT_PNG+1));;
            *.jpg|*.jpeg) COUNT_JPG=$((COUNT_JPG+1));;
        esac
        if [ -f "$f" ]; then
            local s
            s=$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f" 2>/dev/null || echo 0)
            INPUT_TOTAL_BYTES=$((INPUT_TOTAL_BYTES + s))
        fi
    done

    process_image() {
        local input_file="$1"
        local base=$(basename "$input_file")
        local name="${base%.*}"
        local out_file=""

        if [ $NO_FOLDER -eq 1 ]; then
            local file_dir=$(dirname "$input_file")
            out_file="${file_dir}/${name}_resized.${OUTPUT_EXT}"
        else
            out_file="${OUTPUT_DIR}/${name}.${OUTPUT_EXT}"
        fi

        if [ $SKIP_EXISTING -eq 1 ] && [ -f "$out_file" ] && [ "$out_file" -nt "$input_file" ]; then
            info "Saltando (más reciente): $out_file"
            return 0
        fi

        local w=$(sips -g pixelWidth "$input_file" 2>/dev/null | awk '/pixelWidth:/ {print $2}')
        local h=$(sips -g pixelHeight "$input_file" 2>/dev/null | awk '/pixelHeight:/ {print $2}')

        local resize_args=("resize")
        if [[ -n "$max_width" && -n "$max_height" ]]; then
            # Ambas dimensiones proporcionadas: Sharp ajustará para que quepa en el "cuadro"
            resize_args+=("--width" "$max_width" "--height" "$max_height" "--fit" "inside")
        elif [[ -n "$max_width" ]]; then
            resize_args+=("--width" "$max_width")
        elif [[ -n "$max_height" ]]; then
            resize_args+=("--height" "$max_height")
        fi

        if [ $DRY_RUN -eq 1 ]; then
            info "[dry-run] sharp -i \"$input_file\" -o \"$out_file\" --format $OUTPUT_FORMAT -q $OUTPUT_QUALITY ${resize_args[*]}"
        else
            local target_dir=$(dirname "$out_file")
            if npx -y sharp-cli -i "$input_file" -o "$target_dir" --format "$OUTPUT_FORMAT" -q "$OUTPUT_QUALITY" "${resize_args[@]}" >/dev/null 2>&1; then
                # Si estamos en modo no-folder, sharp-cli habrá creado <base>.<ext> en $target_dir.
                # Necesitamos renombrarlo a <name>_resized.<ext>
                if [ $NO_FOLDER -eq 1 ]; then
                   local generated="${target_dir}/${name}.${OUTPUT_EXT}"
                   if [ -f "$generated" ] && [ "$generated" != "$out_file" ]; then
                       mv "$generated" "$out_file"
                   fi
                fi
                echo -e "  ${GREEN}✓${NC} $base -> $OUTPUT_EXT"
            else
                echo -e "  ${RED}✗${NC} Fallo: $base"
                has_errors=1
            fi
        fi
    }

    if [ ${#all_inputs[@]} -gt 0 ]; then
        for f in "${all_inputs[@]}"; do
            process_image "$f"
        done
    else
        error "No se encontraron archivos para procesar."
    fi

    echo ""
    if [ $has_errors -eq 0 ]; then
        if [ $ARTERO_MODE -eq 1 ]; then
            local t0=$(date +%s%3N 2>/dev/null || date +%s000)
            rotate_artero_outputs
            local t1=$(date +%s%3N 2>/dev/null || date +%s000)
            ROTATED_TIME_MS=$((t1 - t0))
        fi
        
        success "¡Proceso completado!"
        success "Imágenes en '$OUTPUT_DIR/'"

        # Notificación de fin (solo macOS)
        if [ $QUIET -eq 1 ] && command -v osascript &>/dev/null; then
            osascript -e "display notification \"¡Proceso completado con éxito!\" with title \"Sharp Resizer\""
        fi

        if [ -d "$OUTPUT_DIR" ]; then
            echo ""
            info "Resumen:"
            file_count=$(ls -1q "$OUTPUT_DIR"/ | wc -l | tr -d ' ')
            
            local current_out_bytes=0
            shopt -s nullglob
            for f in "$OUTPUT_DIR"/*; do
                if [ -f "$f" ]; then
                    s=$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f" 2>/dev/null || echo 0)
                    current_out_bytes=$((current_out_bytes + s))
                fi
            done
            shopt -u nullglob

            in_mb=$(awk -v b=$INPUT_TOTAL_BYTES 'BEGIN{printf "%.2f", b/1048576}')
            out_mb=$(awk -v b=$current_out_bytes 'BEGIN{printf "%.2f", b/1048576}')
            saved=$(awk -v a=$in_mb -v b=$out_mb 'BEGIN{d=a-b; if(d<0)d=0; printf "%.2f", d}')

            echo "  - Total:           $file_count"
            echo "  - Ahorro aprox:    ${saved} MB"
            
            if [ $ARTERO_MODE -eq 1 ]; then
                echo "  - Rotados (-artero): $ROTATED_COUNT"
            fi
        fi
    else
        error "Hubo errores durante el proceso."
    fi
}

main() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Redimensionador Imágenes (CLI/Sharp)${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""

    parse_args "$@"
    check_dependencies
    
    if [ ${#FILE_LIST[@]} -gt 0 ]; then
        collect_files_from_args
    else
        ask_image_type
    fi

    if [ -z "$OUTPUT_EXT" ]; then
        ask_output_type
    fi

    if [ -z "$max_width" ]; then
        ask_max_width
    fi

    ask_max_height

    fix_orientation
    execute_cli
}

main "$@"
