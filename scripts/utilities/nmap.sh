#!/bin/bash
set -euo pipefail

# Colores
greenColour="\e[0;32m\033[1m"
endColour="\033[0m\e[0m"
redColour="\e[0;31m\033[1m"
blueColour="\e[0;34m\033[1m"
yellowColour="\e[0;33m\033[1m"
purpleColour="\e[0;35m\033[1m"
turquoiseColour="\e[0;36m\033[1m"
grayColour="\e[0;37m\033[1m"

# Variables globales
ip=""

# Manejo de interrupciones
trap finish SIGINT

finish() {
    echo -e "\n\n${redColour}[!] Saliendo...${endColour}"
    exit 1
}

# Comprueba si nmap está instalado e intenta instalarlo si no lo está.
check_nmap() {
  if command -v nmap &>/dev/null; then
    return
  fi

  echo -e "${yellowColour}[*] Nmap no está instalado. Intentando instalar...${endColour}"
  if command -v apt-get &>/dev/null; then
    sudo apt-get update >/dev/null 2>&1
    sudo apt-get install nmap -y >/dev/null 2>&1
  elif command -v dnf &>/dev/null; then
    sudo dnf install nmap -y >/dev/null 2>&1
  elif command -v pacman &>/dev/null; then
    sudo pacman -S nmap --noconfirm >/dev/null 2>&1
  else
    echo -e "${redColour}[!] No se pudo determinar el gestor de paquetes. Instale nmap manualmente.${endColour}"
    exit 1
  fi

  if ! command -v nmap &>/dev/null; then
    echo -e "${redColour}[!] No se pudo instalar nmap. Por favor, instálelo manualmente.${endColour}"
    exit 1
  fi
  echo -e "${greenColour}[*] Nmap instalado correctamente.${endColour}"
}

# Solicita y valida la dirección IP objetivo.
get_target_ip() {
  while true; do
    echo -ne "${greenColour}\n[?] Introduce la IP: ${endColour}" && read -r ip
    if ping -c 1 "$ip" &>/dev/null; then
      echo -e "${greenColour}[*] IP activa: $ip${endColour}"
      break
    else
      echo -e "${redColour}[!] La IP $ip no está activa o no es válida.${endColour}"
    fi
  done
}

# Muestra el menú de escaneos y ejecuta la opción seleccionada.
show_menu() {
    while true; do
      echo -e "\n${blueColour}--- MENÚ DE ESCANEO NMAP ---${endColour}"
      echo "1) Escaneo rápido pero ruidoso"
      echo "2) Escaneo Normal"
      echo "3) Escaneo silencioso (lento)"
      echo "4) Escaneo de servicios y versiones"
      echo "5) Escaneo completo (muy ruidoso)"
      echo "6) Escaneo de protocolos UDP" 
      echo "7) Salir"
      echo -ne "${greenColour}\n[?] Seleccione una opcion: ${endColour}" && read -r opcion

      # Ejecutar escaneo
      clear
      echo -e "${yellowColour}[*] Escaneando $ip...${endColour}"
      
      case $opcion in
       1)
         nmap -p- --open --min-rate 5000 -T5 -sS -Pn -n -v "$ip" | grep -E "^[0-9]+\/[a-z]+\s+open\s+[a-z]+"
         ;;
       2)
         nmap -p- --open "$ip" | grep -E "^[0-9]+\/[a-z]+\s+open\s+[a-z]+"
         ;;
       3)
         nmap -p- -T2 -sS -Pn -f "$ip" | grep -E "^[0-9]+\/[a-z]+\s+open\s+[a-z]+"
         ;;
       4)
         nmap -sV -sC "$ip"
         ;;
       5)
         nmap -p- -sS -sV -sC --min-rate 5000 -n -Pn "$ip"
         ;;
       6)
         nmap -sU --top-ports 200 --min-rate=5000 -n -Pn "$ip"
         ;;
       7)
         finish
         ;;
       *)
        echo -e "\n${redColour}[!] Opción no encontrada.${endColour}"
        ;;
      esac
    done
}

# --- Flujo principal ---
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\n${redColour}[!] Debes ser root para ejecutar el script (sudo $0)${endColour}"
    exit 1
fi

clear
check_nmap
get_target_ip
show_menu

