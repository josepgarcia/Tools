# Windows Tools Specification

> [!IMPORTANT]
> **Instrucciones para el agente (Claude Opus 4.5 / Antigravity)**
> 
> 1. Lee **todo el documento** antes de empezar a implementar
> 2. Sigue el **orden de implementación** especificado en la sección correspondiente
> 3. Crea la **estructura de carpetas** antes de escribir los scripts
> 4. El script de imágenes **no tiene dependencias externas** (usa WPF nativo de Windows)
> 5. Los scripts de PDF requieren **qpdf y Ghostscript** - incluye instrucciones de instalación claras en el README
> 6. El menú contextual requiere **permisos de administrador** - avisa al usuario antes de modificar el registro
> 7. **Prueba cada script** después de implementarlo si hay archivos de ejemplo disponibles
> 8. Si tienes dudas sobre algún requisito, **pregunta antes de implementar**

---

## Objetivo

Crear utilidades para Windows equivalentes a las herramientas de productividad de macOS, con integración en el menú contextual del Explorador de Windows.

### Utilidades a implementar:

1. **Redimensionado de imágenes** (JPG, PNG → JPG comprimido, máx 1800px)
2. **Unir PDFs** (múltiples archivos en uno)
3. **Comprimir PDFs** (reducir tamaño manteniendo calidad)
4. **Separar PDFs** (extraer cada página como archivo individual)

---

## Decisiones técnicas

### Lenguaje: PowerShell 7+

**Razones:**
- Nativo en Windows, sin dependencias adicionales de runtime
- Soporte completo para colores, arrays, funciones avanzadas
- Fácil integración con el registro de Windows para menú contextual
- Mejor manejo de rutas y archivos que Batch

**Alternativas descartadas:**
- Python: Requiere instalación adicional, no universal en Windows
- Node.js: Añade dependencia pesada solo para scripting
- Batch (.bat): Muy limitado para lógica compleja

---

### Herramienta para imágenes: PowerShell nativo (WPF Imaging)

**Requisitos simplificados:**
- Entrada: JPG y PNG
- Salida: Solo JPG
- Ancho máximo: 1800px (fijo)
- Sin WebP ni AVIF por el momento

**Decisión:** Usar **WPF Imaging (System.Windows.Media.Imaging)** integrado en Windows

**Razones:**
- ✅ **Sin dependencias externas** - No requiere Node.js, ImageMagick ni nada adicional
- ✅ Nativo en Windows (viene con .NET Framework, presente en todos los Windows modernos)
- ✅ Mejor calidad que System.Drawing (obsoleto)
- ✅ Soporta JPG y PNG de entrada perfectamente
- ✅ Control de calidad de compresión JPG (QualityLevel 0-100)
- ✅ Redimensionado con buena interpolación

**Alternativas descartadas:**

| Herramienta | Razón de descarte |
|-------------|-------------------|
| Sharp (Node.js) | Requiere Node.js instalado - overhead innecesario para solo JPG |
| ImageMagick | Instalación adicional, demasiado pesado para el caso de uso |
| System.Drawing | Obsoleto, peor calidad de redimensionado |

**Código base para el redimensionado:**

```powershell
Add-Type -AssemblyName PresentationCore

function Resize-ImageToJpg {
    param(
        [string]$InputPath,
        [string]$OutputPath,
        [int]$MaxWidth = 1800,
        [int]$Quality = 80
    )
    
    # Cargar imagen original
    $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
    $bitmap.BeginInit()
    $bitmap.UriSource = [Uri](Resolve-Path $InputPath)
    $bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
    $bitmap.EndInit()
    $bitmap.Freeze()
    
    # Calcular escala (solo reducir, nunca ampliar)
    $scale = [Math]::Min(1.0, $MaxWidth / $bitmap.PixelWidth)
    
    # Crear bitmap redimensionado
    $resized = New-Object System.Windows.Media.Imaging.TransformedBitmap(
        $bitmap,
        (New-Object System.Windows.Media.ScaleTransform($scale, $scale))
    )
    
    # Codificar como JPG con calidad especificada
    $encoder = New-Object System.Windows.Media.Imaging.JpegBitmapEncoder
    $encoder.QualityLevel = $Quality
    $encoder.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($resized))
    
    # Guardar archivo
    $stream = [System.IO.File]::Create($OutputPath)
    $encoder.Save($stream)
    $stream.Close()
}
```

---

### Herramientas para PDFs

**Decisión:** Usar **qpdf** + **Ghostscript**

| Operación | Herramienta | Razón |
|-----------|-------------|-------|
| Unir PDFs | qpdf | Rápido, sin pérdida, maneja PDFs complejos |
| Separar PDFs | qpdf | Mismo binario, consistencia |
| Comprimir PDFs | Ghostscript | Mejor ratio de compresión, niveles configurables |

**Distribución de binarios:**

Ambas herramientas tienen binarios precompilados para Windows:
- **qpdf**: https://github.com/qpdf/qpdf/releases (ZIP portable)
- **Ghostscript**: https://ghostscript.com/releases/gsdnld.html (instalador o ZIP)

**Opciones de instalación:**

1. **Recomendado:** El usuario instala via Chocolatey:
   ```powershell
   choco install qpdf ghostscript
   ```

2. **Alternativa:** Incluir binarios portables en el repositorio (carpeta `bin/`)

3. **Verificación:** El script comprueba si están en PATH antes de ejecutar

---

## Estructura del proyecto

```
Windows-Tools/
├── README.md                          # Documentación principal
├── INSTALL.md                         # Guía de instalación paso a paso
│
├── scripts/
│   ├── common/
│   │   └── Common-Functions.ps1       # Funciones compartidas (colores, logging, verificaciones)
│   │
│   ├── images/
│   │   └── Resize-Images.ps1          # Redimensionador de imágenes
│   │
│   └── pdf/
│       ├── Merge-PDFs.ps1             # Unir PDFs
│       ├── Compress-PDF.ps1           # Comprimir PDF
│       └── Split-PDF.ps1              # Separar PDF en páginas
│
├── context-menu/
│   ├── Install-ContextMenu.ps1        # Instalador de menú contextual
│   ├── Uninstall-ContextMenu.ps1      # Desinstalador
│   └── registry-entries.reg           # Alternativa manual (doble clic)
│
└── bin/                               # (Opcional) Binarios portables
    ├── qpdf/
    └── gs/
```

---

## Especificación de cada script

### 1. Resize-Images.ps1

**Funcionalidad:**
- Recibe archivos de imagen (JPG o PNG) como argumentos
- Redimensiona a máximo 1800px de ancho manteniendo proporción
- Convierte todo a JPG con compresión configurable
- Sin dependencias externas (usa WPF nativo de Windows)

**Parámetros:**
```powershell
.\Resize-Images.ps1 
    -InputFiles <string[]>       # Archivos a procesar (JPG, PNG)
    -MaxWidth <int>              # Ancho máximo (px), default: 1800
    -Quality <int>               # Calidad JPG 1-100, default: 80
    -OutputFolder <string>       # Carpeta de salida, default: "resized" junto a originales
    -Suffix <string>             # Sufijo para archivos, default: "" (sin sufijo)
```

**Comportamiento:**
1. Cargar assembly WPF: `Add-Type -AssemblyName PresentationCore`
2. Crear carpeta de salida si no existe
3. Para cada imagen:
   - Cargar con `BitmapImage`
   - Calcular escala: `Min(1, 1800 / anchura_original)` (nunca ampliar)
   - Aplicar `TransformedBitmap` con `ScaleTransform`
   - Guardar con `JpegBitmapEncoder` y `QualityLevel`
4. Mostrar resumen: archivos procesados, tamaño original vs final

**Manejo de orientación EXIF:**
WPF respeta automáticamente la orientación EXIF, no es necesario código adicional.

**Ejemplo de uso desde menú contextual:**
```powershell
# Archivo único
.\Resize-Images.ps1 -InputFiles "C:\Fotos\imagen.jpg"

# Múltiples archivos
.\Resize-Images.ps1 -InputFiles "C:\Fotos\img1.jpg", "C:\Fotos\img2.png"

# Con opciones personalizadas
.\Resize-Images.ps1 -InputFiles "C:\Fotos\*.jpg" -MaxWidth 1200 -Quality 85
```

---

### 2. Merge-PDFs.ps1

**Funcionalidad:**
- Recibe múltiples archivos PDF
- Los une en orden alfabético (o por nombre)
- Genera archivo único

**Parámetros:**
```powershell
.\Merge-PDFs.ps1
    -InputFiles <string[]>       # PDFs a unir
    -OutputFile <string>         # Archivo de salida, default: "merged.pdf" en carpeta del primer archivo
    -SortBy <string>             # "name" (default), "date", "none"
```

**Comando interno:**
```powershell
qpdf --empty --pages $files -- $outputFile
```

---

### 3. Compress-PDF.ps1

**Funcionalidad:**
- Recibe un archivo PDF
- Lo comprime usando Ghostscript
- Ofrece niveles de compresión

**Parámetros:**
```powershell
.\Compress-PDF.ps1
    -InputFile <string>          # PDF a comprimir
    -Level <string>              # "screen", "ebook" (default), "printer", "prepress"
    -OutputFile <string>         # Default: "<nombre>_compressed.pdf"
```

**Niveles de compresión:**
| Nivel | DPI | Uso recomendado |
|-------|-----|-----------------|
| screen | 72 | Solo visualización en pantalla |
| ebook | 150 | **Balance ideal** para compartir |
| printer | 300 | Impresión doméstica |
| prepress | 300+ | Impresión profesional |

**Comando interno:**
```powershell
gswin64c -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 `
    -dPDFSETTINGS=/$Level `
    -dNOPAUSE -dBATCH -dQUIET `
    -sOutputFile="$OutputFile" "$InputFile"
```

---

### 4. Split-PDF.ps1

**Funcionalidad:**
- Recibe un archivo PDF
- Genera un archivo por cada página

**Parámetros:**
```powershell
.\Split-PDF.ps1
    -InputFile <string>          # PDF a separar
    -OutputFolder <string>       # Carpeta de salida, default: "<nombre>_pages/"
    -Prefix <string>             # Prefijo de archivos, default: "page"
```

**Comando interno:**
```powershell
qpdf --split-pages "$InputFile" "$OutputFolder/$Prefix-%d.pdf"
```

---

## Integración con menú contextual de Windows

### Concepto

En Windows, el menú contextual se configura mediante el **Registro de Windows**. Se crean entradas en:
- `HKEY_CLASSES_ROOT\*\shell\` → Para cualquier archivo
- `HKEY_CLASSES_ROOT\SystemFileAssociations\.jpg\shell\` → Para tipos específicos
- `HKEY_CLASSES_ROOT\Directory\Background\shell\` → Para fondo de carpeta

### Entradas a crear

#### Para imágenes (JPG, PNG, JPEG):
```
📁 Redimensionar imagen (1800px)
```

Una sola entrada sencilla. Clic derecho sobre imagen(es) → "Redimensionar imagen (1800px)" → Procesa y guarda en carpeta "resized/".

#### Para PDFs:
```
📁 Herramientas PDF
   ├── Comprimir PDF
   └── Separar en páginas

(Al seleccionar múltiples PDFs):
📁 Unir PDFs seleccionados
```

### Ejemplo de entrada en el registro

```reg
; Para archivos .jpg
[HKEY_CLASSES_ROOT\SystemFileAssociations\.jpg\shell\ResizeImage]
@="Redimensionar imagen"
"Icon"="imageres.dll,-5205"
"SubCommands"=""

[HKEY_CLASSES_ROOT\SystemFileAssociations\.jpg\shell\ResizeImage\command]
@="powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"C:\\Tools\\scripts\\images\\Resize-Images.ps1\" \"%1\""
```

### Script de instalación

`Install-ContextMenu.ps1` debe:
1. Solicitar elevación (Run as Administrator)
2. Preguntar ruta de instalación de los scripts
3. Crear todas las entradas del registro
4. Verificar que las dependencias de PDF están instaladas (qpdf, gs)
5. Opcionalmente añadir binarios al PATH

---

## Gestión de dependencias

### Verificación al inicio de cada script

```powershell
function Test-Dependency {
    param([string]$Command, [string]$InstallHint)
    
    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        Write-Host "[ERROR] $Command no encontrado." -ForegroundColor Red
        Write-Host "Instalar con: $InstallHint" -ForegroundColor Yellow
        exit 1
    }
}

# Resize-Images.ps1 NO necesita verificación de dependencias (usa WPF nativo)

# En scripts PDF
Test-Dependency "qpdf" "'choco install qpdf' o https://github.com/qpdf/qpdf/releases"
Test-Dependency "gswin64c" "'choco install ghostscript' o https://ghostscript.com"
```

---

## Interfaz de usuario

### Colores en PowerShell

```powershell
function Write-Info    { param($msg) Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Success { param($msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Warning { param($msg) Write-Host "[AVISO] $msg" -ForegroundColor Yellow }
function Write-Error   { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }
```

### Notificaciones de Windows

```powershell
# Notificación toast nativa (Windows 10+)
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
# ... o usar módulo BurntToast para simplificar:
# Install-Module -Name BurntToast
New-BurntToastNotification -Text "Proceso completado", "5 imágenes redimensionadas"
```

---

## Consideraciones adicionales

### Rutas con espacios
PowerShell maneja bien las rutas con espacios si se usan comillas. Asegurar que todos los paths se pasen entrecomillados.

### Archivos bloqueados
Verificar que el archivo no esté abierto por otra aplicación antes de procesar.

### Nombres de archivo
- Sanitizar caracteres especiales
- Evitar sobrescribir archivos existentes (añadir numeración si es necesario)

### Logging
Crear archivo de log en `%TEMP%\WindowsTools\` para debug.

### Códigos de salida
- `0` = Éxito
- `1` = Error de dependencias
- `2` = Error de argumentos
- `3` = Error de procesamiento

---

## Orden de implementación recomendado

1. **Common-Functions.ps1** - Base compartida
2. **Resize-Images.ps1** - Sin dependencias externas, probar WPF Imaging
3. **Install-ContextMenu.ps1** - Para poder probar el flujo completo
4. **Merge-PDFs.ps1** - Más simple de los PDF
5. **Split-PDF.ps1** - Similar a merge
6. **Compress-PDF.ps1** - Requiere más opciones

---

## Testing

### Manual
1. Ejecutar cada script desde PowerShell con archivos de prueba
2. Verificar que el menú contextual aparece correctamente
3. Probar con archivos que tengan espacios y caracteres especiales en el nombre

### Archivos de prueba sugeridos
- Imagen horizontal grande (4000x3000)
- Imagen vertical grande (3000x4000)
- Imagen pequeña (menor que el target)
- PDF simple (pocas páginas)
- PDF grande (muchas páginas, con imágenes)
- PDF protegido (para verificar manejo de errores)

---

## Referencias

- [qpdf Documentation](https://qpdf.readthedocs.io/)
- [Ghostscript Documentation](https://ghostscript.com/docs/)
- [WPF Imaging Overview](https://docs.microsoft.com/en-us/dotnet/desktop/wpf/graphics-multimedia/imaging-overview)
- [Windows Context Menu Registry](https://docs.microsoft.com/en-us/windows/win32/shell/context-menu-handlers)
- [PowerShell Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/developer/cmdlet/cmdlet-development-guidelines)
