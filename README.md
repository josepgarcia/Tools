# Tools

## Añadir nuevo repo
```bash
submodule add https://github.com/twbs/bootstrap vendor/bootstrap
```

## Actualiar todos
Si tenemos muchos módulos
```bash
git submodule update --remote --recursive
```

La más sencilla, pull + fetch + actualización de submódulos, lo deja todo al día
```bash
git pull --recurse-submodules
```
