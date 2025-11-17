```
 _____ ___   ___  _     ____
|_   _/ _ \ / _ \| |   / ___|
  | || | | | | | | |   \___ \
  | || |_| | |_| | |___ ___) |
  |_| \___/ \___/|_____|____/
```

Colección de herramientas y scripts de seguridad y utilidades.

## Estructura

- **`scripts/`**: Scripts personales organizados por categoría

  - `backup/`: Scripts de respaldo de bases de datos
  - `utilities/`: Utilidades generales (nmap, procesamiento de imágenes, etc.)

- **Herramientas de seguridad (submodules)**
  - [`domain_analyzer`](security/domain_analyzer): Análisis de dominios
  - [`PHP-Antimalware-Scanner`](security/PHP-Antimalware-Scanner): Escáner de malware PHP
  - [`WhatWeb`](security/WhatWeb): Identificación de tecnologías web

## Uso Rápido

### Actualizar todo

```bash
./update.sh
```

### Añadir nuevo submódulo

```bash
git submodule add <URL>
```

### Usar herramientas de seguridad

**Domain Analyzer:**

```bash
cd domain_analyzer
python domain_analyzer.py -d example.com
```

**PHP Antimalware Scanner:**

```bash
cd PHP-Antimalware-Scanner
php scan.php /path/to/scan
```

**WhatWeb:**

```bash
cd WhatWeb
./whatweb example.com
```
