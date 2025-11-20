```
 _____ ___   ___  _     ____
|_   _/ _ \ / _ \| |   / ___|
  | || | | | | | | |   \___ \
  | || |_| | |_| | |___ ___) |
  |_| \___/ \___/|_____|____/
```

Colección de herramientas y scripts de seguridad y utilidades para desarrollo y análisis.

## 🚀 Instalación

### Instalación Rápida

```bash
# 1. Clonar el repositorio
git clone <URL_DEL_REPO> ~/Developer/Tools
cd ~/Developer/Tools

# 2. Inicializar submódulos
git submodule update --init --recursive

# 3. Crear enlace simbólico al comando tools
mkdir -p ~/bin
ln -s ~/Developer/Tools/tools ~/bin/tools
chmod +x ~/Developer/Tools/tools

# 4. Añadir ~/bin al PATH (si no está)
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# 5. Actualizar todas las herramientas
tools update
```

### Requisitos

- **Git** (con soporte para submódulos)
- **Bash** 4.0+
- **Herramientas específicas** (según lo que uses):
  - Ruby + Bundler (para WhatWeb)
  - Python 3 + pip (para domain_analyzer)
  - PHP + Composer (para PHP-Antimalware-Scanner)

## 📁 Estructura del Proyecto

```
Tools/
├── tools                    # Script centralizado de ejecución
├── update.sh               # Script de actualización (deprecated, usar 'tools update')
├── README.md
│
├── scripts/                # Scripts personalizados
│   ├── backup/
│   │   ├── mysql_backup.sh
│   │   └── mysqlBackup.sh
│   ├── utilities/
│   │   ├── nmap.sh
│   │   ├── redimensionar_imagenes.sh
│   │   └── tips_bash.sh
│   └── WordPress/
│       ├── wp-create.sh           # Crear instalación WordPress
│       ├── wp-delete.sh           # Eliminar instalación WordPress
│       ├── wp-setup-env.sh        # Configurar entorno (carpeta + BD)
│       ├── wp-plugin-create.sh    # Crear estructura de plugin
│       ├── config.file
│       ├── README.md
│       └── TODO
│
└── [Submódulos]            # Herramientas de seguridad
    ├── domain_analyzer/    # Análisis de dominios
    ├── PHP-Antimalware-Scanner/  # Escáner de malware PHP
    └── WhatWeb/           # Identificación de tecnologías web
```

## 💻 Uso

### Comando Centralizado `tools`

Todas las herramientas están disponibles a través del comando `tools`:

```bash
tools <comando> [opciones]
```

Ver ayuda completa:

```bash
tools help
# o
tools --help
```

## 📚 Comandos Disponibles

### 🔧 Gestión

```bash
# Actualizar todas las herramientas y submódulos
tools update
```

### 🔒 Seguridad

```bash
# Identificar tecnologías web
tools whatweb example.com

# Analizar dominio
tools domain-analyzer -d example.com

# Escanear malware PHP
tools php-scanner /path/to/scan
```

### 🌐 WordPress

```bash
# Crear nueva instalación de WordPress
tools wp-create nombre-proyecto

# Eliminar instalación de WordPress
tools wp-delete nombre-proyecto

# Configurar entorno (carpeta + base de datos)
tools wp-setup-env nombre-proyecto

# Crear estructura de nuevo plugin
tools wp-plugin-create mi-plugin
```

### 💾 Backup

```bash
# Respaldar base de datos MySQL
tools mysql-backup nombre-bd
```

### 🛠️ Utilidades

```bash
# Ejecutar escaneo con nmap
tools nmap [opciones]

# Redimensionar imágenes
tools resize-images /ruta/a/imagenes
```

## 📖 Uso Directo de Herramientas

Si prefieres usar las herramientas directamente sin el comando `tools`:

### Domain Analyzer

```bash
cd ~/Developer/Tools/domain_analyzer
python domain_analyzer.py -d example.com
```

### PHP Antimalware Scanner

```bash
cd ~/Developer/Tools/PHP-Antimalware-Scanner
php scan.php /path/to/scan
```

### WhatWeb

```bash
cd ~/Developer/Tools/WhatWeb
./whatweb example.com
```

## 🔄 Gestión de Submódulos

### Añadir nuevo submódulo

```bash
cd ~/Developer/Tools
git submodule add <URL_DEL_REPO> <directorio>
git commit -m "Añadido nuevo submódulo: <nombre>"
```

### Actualizar submódulos manualmente

```bash
# Actualizar todos los submódulos
git submodule update --remote --merge

# Actualizar un submódulo específico
git submodule update --remote --merge <directorio>
```

### Clonar repositorio con submódulos

```bash
# Opción 1: Clonar e inicializar en un paso
git clone --recurse-submodules <URL_DEL_REPO>

# Opción 2: Clonar primero, luego inicializar
git clone <URL_DEL_REPO>
cd Tools
git submodule update --init --recursive
```

### Eliminar submódulo

```bash
# 1. Desregistrar el submódulo
git submodule deinit -f <ruta/al/submodulo>

# 2. Eliminar del índice de git
git rm -f <ruta/al/submodulo>

# 3. Eliminar del directorio .git
rm -rf .git/modules/<ruta/al/submodulo>

# 4. Commit de los cambios
git commit -m "Eliminado submódulo: <nombre>"
```

## 🤝 Contribuir

Para añadir nuevos scripts o herramientas:

1. Añade tu script en la carpeta apropiada (`scripts/`)
2. Actualiza el script `tools` para incluir el nuevo comando
3. Actualiza este README con la documentación
4. Haz commit de los cambios

## 📝 Notas

- El script `update.sh` en la raíz está deprecated. Usa `tools update` en su lugar.
- Los scripts de WordPress requieren configuración en `scripts/WordPress/config.file`
- Todos los scripts tienen permisos de ejecución y están documentados internamente

## 📄 Licencia

Ver archivos LICENSE individuales en cada submódulo.
