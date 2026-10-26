# Sitio legal de Ley al Blanco (estático)

Portada (`index.html`) y política de privacidad (`privacidad/index.html`). Sin JavaScript, sin dependencias externas, sin cookies ni rastreo.

- La política se genera desde `docs/legal/politica-privacidad.md` (sin la sección «Notas para el titular»): `python -I web/legal/md2html.py`. Si editas el markdown, regenera; el test falla si no coinciden.
- Tests: `python -m pytest web/legal`.

## 1. Rellenar los marcadores
```
python -I web/legal/rellenar.py --titular "Nombre Apellidos" --correo "soporte@ejemplo.com" --fecha 2026-11-01 [--plazo-correos "un año desde la última respuesta"]
```
Genera `web/legal/dist/` (ignorada por git) y falla si falta algún valor o queda un marcador (`[TITULAR]`, `[CORREO_SOPORTE]`, `[FECHA]`, `[PLAZO_CORREOS]`). Revisa antes las notas del final de `docs/legal/politica-privacidad.md`.

## 2. Publicar en GitHub Pages
La política se publica en el repositorio público (https://github.com/dferrandizmont/ley-al-blanco), en la rama `gh-pages`, con el contenido de `web/legal/dist/`:
1. Genera `dist` con el paso 1.
2. Sube su contenido a la raíz de la rama `gh-pages` del repositorio público, con un único commit y sin historial de la rama principal.
3. En el repositorio > **Settings** > **Pages** > **Deploy from a branch** > `gh-pages` / `(root)`.

Queda en `https://dferrandizmont.github.io/ley-al-blanco/` (portada) y `https://dferrandizmont.github.io/ley-al-blanco/privacidad/` (política). Para actualizar, regenera `dist` y vuelve a subirlo a `gh-pages`.

## 3. En la app y las fichas
- Build de release: `--dart-define=PRIVACY_URL=https://dferrandizmont.github.io/ley-al-blanco/privacidad/`
- Fichas de tienda: política = esa URL; sitio web = `https://dferrandizmont.github.io/ley-al-blanco/`. Ver la [ficha de tienda](../../docs/ficha-tienda.md).
