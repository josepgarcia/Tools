#!/bin/bash
echo "Actualizando repositorio y submódulos..."
git pull --recurse-submodules

if [ $? -eq 0 ]; then
    echo "✓ Actualización completada exitosamente"
else
    echo "✗ Error durante la actualización"
    exit 1
fi
