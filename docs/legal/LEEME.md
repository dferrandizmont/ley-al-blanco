# Documentos legales (borradores)

Borradores pendientes de las decisiones del titular. No son asesoramiento jurídico; conviene que los revise un profesional antes del lanzamiento.

| Fichero | Qué es | Qué falta |
|---|---|---|
| `politica-privacidad.md` | Política de privacidad para publicar (RGPD y LOPDGDD), en tuteo. Refleja `docs/privacy.md`, que es la fuente de verdad. | Rellenar los marcadores y revisar las «Notas para el titular» al final, que el generador HTML **omite**. |

## Publicar la política de privacidad
1. Elegir una URL pública y estable para alojar la política.
2. Generar el HTML con `python -I web/legal/md2html.py`, que omite la sección «Notas para el titular». Ver [el sitio legal](../../web/legal/LEEME.md).
3. Pasar la URL en el build de release con `--dart-define=PRIVACY_URL=https://...` (sin ella, Ajustes no muestra «Política de privacidad»).
4. Poner la misma URL de privacidad en las dos tiendas.
5. Si cambia el flujo de datos, actualizar `docs/privacy.md`, esta política y las declaraciones de las tiendas a la vez.
