# Extraccion y validacion del cuestionario (Guardia Civil, licencias D/E/AEM)

Genera `app/assets/content/armas/<edicion>/questions.json` y `manifest.json`
a partir de los PDF oficiales de `fuentes/guardia-civil/`, y un informe de
validacion en `tool/content/reports/<edicion>.md` y `.json`.

## Requisitos

- Python 3.11 o superior.
- `pdftotext` de **xpdf** o **poppler** en el `PATH`
  (macOS: `brew install poppler`; Debian/Ubuntu: `apt install poppler-utils`;
  Windows: xpdf command line tools o poppler).
- Dependencias Python: `pip install -r tool/content/requirements.txt`
  (PyMuPDF y pytest).

## Como funciona (hibrido)

- **Texto**: `pdftotext -layout -enc UTF-8` sobre `temaN.pdf`. Es el unico
  extractor que decodifica bien acentos y comillas en estos PDF.
- **Respuesta correcta**: PyMuPDF detecta la opcion en **negrita** en
  `temaNr.pdf`. Su texto no ASCII no se usa (sale corrupto); solo la
  estructura y la negrita.
- Ambos se alinean por (numero de pregunta, letra de opcion) y se comprueba
  que ven las mismas preguntas y 3 opciones cada una.

## Ejecutar

Desde la raiz del repositorio:

```
python tool/content/extract_questions.py \
  --src fuentes/guardia-civil --edition GC-2020-11 --retrieved 2026-10-18 \
  --out app/assets/content/armas/GC-2020-11 \
  --report tool/content/reports/GC-2020-11 \
  [--explanations tool/content/explanations/GC-2020-11]
```

Codigo de salida: `0` sin ERROR de validacion; `1` si hay algun ERROR; `2` si
falta `pdftotext`, PyMuPDF o un PDF. La salida es determinista (sin fechas ni
orden aleatorio): ejecutarlo dos veces da ficheros identicos byte a byte.
Con algun ERROR solo se escribe el informe: `questions.json` y `manifest.json`
(los que consume la app) no se tocan, y una pregunta sin respuesta oficial unica
es un ERROR (`respuesta_presente`), nunca un `answer: null`.

Tests: `python -m pytest tool/content/tests -q` (el test de integracion se
omite si no hay `pdftotext`).

## Explicaciones y avisos propios

Capa **nuestra** sobre el cuestionario (nunca altera enunciado, opciones ni
respuesta oficial). Vive en `tool/content/explanations/<edicion>/t1.json ..
t7.json`, un array de entradas por tema (esquema: `explanations/schema.json`):

```json
{"id": "t2-017", "explanation": "1-2 frases propias", "article": "Art. 3 RD 137/1993",
 "notice": "Ojo: el cuestionario dice X; tras la reforma de 2023 el art. Y dice Z.",
 "flags": ["discrepancia_reforma_2023"], "confidence": "alta|media|baja",
 "sources": [{"norma": "BOE-A-1993-6202", "ref": "art. 3"}],
 "reviewed": false, "review_notes": "interno, no se publica"}
```

`extract_questions.py` las fusiona por `id` tras extraer y validar (opcion
`--explanations DIR`; por defecto `tool/content/explanations/<edicion>` si
existe). Se publica `explanation` (`{"es": ...}`), `article`, `notice`
(`{"es": ...}` o `null`), los `flags` (se anaden a los del extractor, sin
duplicar) y `reviewed`. `confidence`, `sources` y `review_notes` son internos
(revision) y **no** salen en `questions.json`. Una pregunta sin entrada queda
con `explanation`, `article` y `notice` a `null` y `reviewed: false`.

Validacion (cualquier ERROR impide escribir `questions.json`/`manifest.json`):
id desconocido, duplicado o en el fichero de otro tema; explicacion vacia o de
mas de 320 caracteres; `notice` sin flag `discrepancia_*` o al reves;
`reviewed: true` sin `article` salvo flag `sin_articulo`; campos desconocidos,
`confidence` fuera de alta/media/baja, tipos incorrectos.

El informe lleva la seccion **Explicaciones**: cobertura por tema, recuento por
confianza, lista de avisos y lista de `confidence: baja`. Con todos los
ficheros vacios, `questions.json` sale igual que sin la opcion (salvo la clave
`"notice": null` de cada pregunta).

Nunca se edita `questions.json` a mano: tras cambiar un fichero de
`explanations/`, se regenera con el comando de arriba (el manifiesto recalcula
`questions_sha256`).

## Cifras y plazos (flag `cifras`)

Marca las preguntas cuya clave es una cifra, un plazo, una edad, una cantidad, un calibre
o un importe (las «trampas» del examen) para el modo de práctica «Cifras y plazos». Capa
**nuestra**: solo anade `cifras` a `flags` en `questions.json`; nunca toca enunciado,
opciones ni respuesta oficial. Regenerar el banco cambia solo ese flag y el
`questions_sha256` del manifiesto.

- `cifras_flag.py`: heuristica determinista sobre enunciado y opciones (cantidad = numero,
  en cifra o en letra, mas una unidad: anos, dias, meses, euros, cartuchos, mm, julios...; el
  numero de categoria «3ª.2» no cuenta). Una pregunta lleva el flag si (A) dos o mas opciones
  llevan cantidades distintas, (B) el enunciado pregunta «cuantos/as» y una opcion empieza
  por un numero, (C) el enunciado fija una medida (julios, mm, cm, calibre N) o (D) la
  opcion correcta lleva una cantidad.
- `cifras/<edicion>.json`: correcciones manuales versionadas, `{"incluir": {id: motivo},
  "excluir": {id: motivo}}`; mandan sobre la heuristica y cada una lleva su motivo. Un id
  desconocido, repetido o en las dos listas es un ERROR. Opcion `--cifras FICHERO`; por
  defecto `tool/content/cifras/<edicion>.json` si existe.
- El informe (`reports/<edicion>.md`) lleva la seccion **Cifras y plazos**: total, reparto por
  tema y las inclusiones/exclusiones manuales.
- Tests: `python -m pytest tool/content/tests/test_cifras.py`.

Todos los temas y modos estan disponibles gratuitamente. El tema 1 no tiene
preguntas de cifras; este modo reune las de los otros temas.

## Comprobar que las fuentes siguen vigentes

`check_sources.py` lee la tabla de `fuentes/guardia-civil/LEEME.md` (fichero,
URL y sha256 de cada PDF), descarga hoy cada URL a una carpeta temporal y
compara el sha256 y la cabecera `Last-Modified`. No toca `fuentes/` ni el
banco. Ejecutarlo **antes de cada version** (`docs/qa.md`).

```
python tool/content/check_sources.py            # descarga y compara
python tool/content/check_sources.py --offline  # solo ficheros locales vs LEEME, sin red
```

Codigo de salida: `0` todo coincide; `1` hay diferencias (el informe dice que
fichero cambio y con que sha256 / `Last-Modified`) o una descarga fallo; `2` el
LEEME no se puede leer o no tiene tabla. Si algo cambio, no regenerar el banco
a ciegas: leer el cambio, descargar los PDF nuevos a `fuentes/`, actualizar el
LEEME (y la fecha `--retrieved`) y volver a ejecutar el pipeline. La tabla
admite una cuarta columna opcional con el `Last-Modified` conocido, que
entonces tambien se compara.

## Leer el informe

`reports/<edicion>.md` empieza con una tabla resumen (OK / WARN / ERROR) y
luego el detalle de cada comprobacion:

- **ERROR**: hay que resolverlo antes de usar el contenido (recuentos que no
  cuadran, numeracion rota, no hay exactamente 3 opciones o 1 negrita...).
- **WARN**: revisar a mano, no bloquea (enunciados repetidos, negrita parcial,
  diferencias temaN/temaNr, lineas ignoradas, fechas de creacion distintas).
- Cada pregunta lleva `flags` en `questions.json`: `pdf_text_mismatch`
  (texto distinto entre `temaN` y `temaNr`) y `answer_partial_bold` (la negrita
  cubria solo la letra o solo el texto de la opcion).
- `reports/<edicion>.json` es lo mismo en formato maquina.
- `manifest.json` incluye `questions_sha256` (la app lo verifica al importar).

## Regla de oro: no alterar el texto

El cuestionario se reutiliza citando fuente y fecha y **sin alterar su sentido**
(Ley 37/2007). El extractor solo une lineas partidas con un espacio, colapsa
espacios y recorta; conserva puntuacion, comillas y erratas originales
(p. ej. `?.`). Si algo esta mal en los PDF, **se informa en el informe, no se
corrige aqui**. No hay fichero de correcciones manuales.

## Teoria (resumenes y «La prueba practica»)

`build_teoria.py` valida `tool/content/teoria/<edicion>/t1.json .. t7.json` y
`practica.json` (esquema en `docs/teoria-guia.md`) y los empaqueta en
`app/assets/content/armas/<edicion>/teoria.json`, ademas de anadir
`teoria_sha256` (sha256 de los bytes exactos de `teoria.json`) al
`manifest.json` ya existente; no toca `questions.json` ni el resto del
manifiesto. `extract_questions.py` conserva el campo al regenerar el banco
(recalcula el sha del `teoria.json` que haya), asi que el orden da igual.

```
python tool/content/build_teoria.py --edition GC-2020-11   --out app/assets/content/armas/GC-2020-11
```

Valida de forma estricta: `id` igual al nombre del fichero, `tema` 1-7 (`null`
en practica), 3-6 secciones, bloques `p` (<= 400 caracteres), `list`, `table`
(2-4 columnas, filas rectangulares, celdas <= 60), `key`, `notice` y `diagram`
(`galeria_tiro`, `zona_segura`, `secuencia` con `items`), `articles` con
formato «Art. N ...», «Arts. ...», «Anexo ...», «Apdo. ...» o «Disp. ...»
(vacios solo si `review_notes` lo justifica), `related_questions` que existan
en `questions.json`, `confidence` alta|media|baja y ningun campo desconocido.
Los titulos de seccion no se repiten dentro de un documento (sin distinguir
mayusculas ni tildes).
`confidence`, `sources`, `review_notes` y `reviewed` son internos y no se copian
al asset. Orden estable (t1..t7, practica, aem, glosario), LF, UTF-8.

`aem.json` y `glosario.json` (`tema` null, gratis) son **opcionales**: si el
fichero no existe, el build sale bien sin ellos; si existe, se valida igual.
`aem` sigue las reglas de un tema (3-6 secciones); `glosario` admite 4-8
secciones y usa el bloque `terms` (`items` de `{term <= 60, text <= 240,
article?}`, con 40-120 terminos en total y ninguno repetido, sin distinguir
mayusculas ni tildes).

Codigo de salida: `0` correcto; `1` si algo no valida (no se escribe nada, los
errores salen por stderr); `2` si falta un fichero de entrada o `questions.json`
/ `manifest.json` en `--out`. `--partial` permite construir con solo parte de
los documentos (desarrollo; no usar para publicar). Tests:
`python -m pytest tool/content/tests/test_teoria.py`.

La app solo muestra Teoria si el manifiesto trae `teoria_sha256` y coincide con
`teoria.json`; si falta cualquiera de los dos, la entrada se oculta.
