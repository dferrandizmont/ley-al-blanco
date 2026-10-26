# Guía de los resúmenes de teoría y de «La prueba práctica»

Spec §4 P1: **resúmenes de teoría por tema** (1 página por tema, con tablas: categorías, licencias y vigencias, sanciones) y una sección **«La prueba práctica»** (protocolo de seguridad, qué se valora, errores que te eliminan; solo texto y diagramas, nunca imágenes de armas).

Valen todas las reglas de [explicaciones-guia.md](explicaciones-guia.md): redacción propia, datos legales solo del corpus del BOE (`tool/content/boe/`, `python -I tool/content/boe/buscar.py`), nada inventado, español claro de tú, sin exclamaciones ni emojis, y avisos cuando la norma vigente difiere de lo que pide el cuestionario.

## Para quién y para qué

Para repasar en 5 minutos lo que entra en cada tema **antes** de practicar, o después de fallar. No sustituye al Reglamento: lo ordena. Cada dato importante lleva su artículo, y si el cuestionario de 2020 espera una cifra distinta de la vigente se dice las dos cosas, como en los avisos de las preguntas.

## Ficheros

- Fuente: `tool/content/teoria/GC-2020-11/t{1..7}.json` y `practica.json` (uno por documento).
- El pipeline los valida y los copia a `app/assets/content/armas/GC-2020-11/teoria.json` (todos juntos), con su sha256 en `manifest.json`. No se edita el asset a mano.

## Esquema de un documento

```json
{
  "id": "t2",                       // "t1".."t7" o "practica"
  "tema": 2,                        // null en "practica"
  "title": "Categorías de armas",
  "summary": "Una o dos frases: de qué va y qué es lo que más cae.",
  "sections": [
    {
      "title": "Las nueve categorías",
      "collapsed": false,           // las tablas largas pueden ir plegadas
      "blocks": [
        { "type": "p", "text": "Párrafo corto (≤ 400 caracteres)." },
        { "type": "list", "items": ["Elemento", "Elemento"] },
        { "type": "table", "caption": "Opcional", "headers": ["Categoría", "Qué incluye", "Licencia"],
          "rows": [["1.ª", "Armas cortas: pistolas y revólveres", "B"]] },
        { "type": "key", "text": "Lo que más cae en el examen: …" },
        { "type": "notice", "text": "Ojo: el cuestionario de 2020 dice X; hoy el art. N dice Z." },
        { "type": "diagram", "kind": "galeria_tiro", "caption": "…" }
      ],
      "articles": ["Art. 3 RD 137/1993"]   // fuentes de la sección (formato fijo)
    }
  ],
  "related_questions": ["t2-001", "t2-010"],   // ids del banco que este texto ayuda a responder
  "confidence": "alta|media|baja",
  "sources": [{ "norma": "BOE-A-1993-6202", "ref": "art. 3" }],
  "review_notes": "",
  "reviewed": false
}
```

Tipos de bloque: `p`, `list`, `table`, `key` (recuadro «Clave para el examen»), `notice` (aviso de cambio de norma, mismo estilo que en las preguntas) y `diagram`. Los diagramas los dibuja la app (no son imágenes); de momento hay estos `kind`:
- `galeria_tiro`: puesto de tiro, línea de tiro y diana a 25 m (prueba práctica de rifle).
- `zona_segura`: sector de tiro con la dirección segura del cañón.
- `secuencia`: pasos numerados (usa `items` como en `list`).

## Extensión y forma

- **Un tema = una «página»**: 3–6 secciones; en total, unos 1.500–3.000 caracteres sin contar tablas.
- Tablas: 2–4 columnas, celdas cortas (≤ 60 caracteres) para que quepan en un móvil pequeño.
- **Tiempo de lectura** («N min de lectura»): la app lo calcula a ~900 caracteres por minuto con el título, el resumen, las secciones y **también el texto de las tablas** (cabeceras y celdas); los diagramas cuentan por sus pasos. El límite de 1.500–3.000 caracteres de arriba sigue sin contar tablas, pero el tiempo mostrado sí.
- **Título de los temas (`t1`..`t7`)**: el que enseña la app sale siempre de los nombres del programa oficial de `lib/l10n/app_es.arb` (`tema1`..`tema7`, los mismos que Inicio, la práctica y el resultado). El `title` del JSON se mantiene igual a ese nombre (un test lo comprueba); `practica`, `aem` y `glosario` usan su propio `title`.
- **Cifra y unidad juntas**: `build_teoria.py` cambia por un espacio duro (U+00A0) el espacio entre una cifra y «€», «%», «m», «cm», «mm», «km», «kg», «g», «J», «julios», «años», «días», «meses» o «euros», para que el símbolo no quede solo al principio de una línea («30.001 a 600.000 / €»). Se escribe con espacio normal en la fuente; el asset lo lleva ya duro.
- Los recuadros «Clave para el examen» (`key`) no repiten el rótulo: la app ya pone «Clave para el examen» como título del recuadro, así que el texto empieza directamente por el dato (la app también quita un prefijo antiguo «Lo que más cae:» que aún lleven las fuentes).
- Cada sección con al menos un artículo en `articles`, salvo lo puramente técnico (tema 1, parte del 7), que se marca en `review_notes`.
- **Nunca** dibujar ni describir cómo apuntar a una persona; nada sobre fabricar, modificar o comprar armas fuera de lo que exige el temario (spec §4.5).

## La prueba práctica (`practica.json`)

Fuentes: Resolución de 19-10-1998 (anexo II) y Orden de 18-3-1998 en el corpus, más la resolución de 2024 si cambia algo. Contenido: en qué consiste (rifle: 5 disparos a 25 m, al menos 1 impacto; escopeta: 2 disparos), cómo se desarrolla, qué se valora (seguridad y manejo), **errores que eliminan** (dirigir la boca del arma fuera de la zona, disparar antes o después de la señal, dejar cartuchos sin disparar…, según el anexo), tasas si están en el corpus, y consejos de seguridad generales (sin técnica de tiro avanzada). Ilustraciones: solo `galeria_tiro`, `zona_segura` y `secuencia`.

## Proceso

Igual que las explicaciones: redacta Opus, verifica Fable contra el corpus, aplico las correcciones y valida el pipeline.

## Glosario (`glosario.json`) y AEM (`aem.json`)

Dos documentos más con el mismo esquema y el mismo pipeline, ambos **gratis**, con `"tema": null`:

- **`glosario`** (spec §4 P1): los términos que más confunden en el examen, agrupados en 4–8 secciones temáticas (p. ej. «Categorías de armas», «Licencias, guías y tarjetas», «Piezas y funcionamiento», «Munición», «Términos legales»). Usa sobre todo el bloque nuevo **`terms`**:
  ```json
  { "type": "terms", "items": [
    { "term": "Guía de pertenencia", "text": "Documento de cada arma que acredita quién es su titular (≤ 240 caracteres).", "article": "Art. 88 RD 137/1993" }
  ] }
  ```
  `term` ≤ 60 caracteres, `text` ≤ 240, `article` opcional con el mismo formato que `articles`. Entre 40 y 120 términos en total, ordenados alfabéticamente dentro de cada sección; un término no se repite entre secciones. Las secciones del glosario pueden tener hasta 8 y no cuentan para el límite de 1.500–3.000 caracteres de prosa. `related_questions` puede ir vacío.
- **`aem`** (spec §4 P1, «pestaña AEM»): la autorización especial para menores (14 a 17 años): qué es, quién puede pedirla y a qué edad, qué armas y para qué (caza, tiro deportivo), requisitos (consentimiento, acompañamiento, pruebas, informe), vigencia y qué pasa al cumplir 18. Mismas reglas de extensión que un tema (3–6 secciones). Fuentes: art. 109 RD 137/1993 y lo que haya en el corpus. Sin datos que no estén en el corpus.

Orden en `teoria.json`: t1..t7, practica, aem, glosario.
