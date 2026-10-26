# Guía para escribir las explicaciones

Las explicaciones son lo que diferencia la app (spec §1, §3.3.5, §4.2): **entender, no memorizar**. Un error aquí hunde la nota en las reseñas, así que la precisión manda sobre todo lo demás.

Ficheros: `tool/content/explanations/GC-2020-11/t{1..7}.json` (esquema en `schema.json`). El pipeline (`tool/content/extract_questions.py`) los fusiona en el banco; **nunca** se edita `questions.json` a mano.

## Reglas que no se rompen

1. **La respuesta oficial no se toca.** La explicación justifica la opción marcada en el cuestionario de la Guardia Civil. Si la norma vigente dice otra cosa, se explica la oficial y se añade un **aviso** (ver abajo).
2. **Redacción propia.** Nada copiado de academias, blogs, foros ni otras apps. Sí se puede citar literalmente la norma (no tiene derechos de autor, art. 13 LPI), pero una cita literal larga no es una explicación: se explica con palabras sencillas.
3. **Solo fuentes oficiales para lo legal.** El artículo citado tiene que existir en el corpus del BOE (`tool/content/boe/`, buscador: `python -I tool/content/boe/buscar.py "palabras"`) y decir lo que la explicación afirma. Si no lo encuentras, no lo inventes: `article: null`, `confidence: "baja"` y explica en `review_notes` qué falta.
4. **Nada de inventar cifras, plazos ni importes.** Todo dato concreto (años de vigencia, euros de multa, edades, metros, plazos) sale del artículo citado.

## Forma

- **1 o 2 frases, máximo 320 caracteres.** Primero el porqué de la correcta; si una opción incorrecta es una trampa típica, una frase corta sobre por qué no.
- Español claro, de tú, sin jerga innecesaria, sin exclamaciones ni emojis. Pensado para alguien de 50–70 años que estudia en ratos libres y para un chaval de 16 con la AEM.
- No repetir el enunciado. No empezar con «La respuesta correcta es…» (la app ya lo muestra).
- Las opciones del tipo «Ambas son correctas» / «Las dos anteriores»: explicar por qué valen las dos.
- `article`: formato fijo **«Art. 3 RD 137/1993»**, «Art. 36.9 LO 4/2015», «Anexo I RD 137/1993». Un solo artículo, el más concreto (apartado si aporta). Varios fuentes van en `sources`.

### Ejemplos de tono (inventados, no son del banco)

- ✔ «La licencia E ampara escopetas y armas asimiladas para caza y tiro deportivo; los rifles de caza mayor necesitan la licencia D.» · `Art. 3 RD 137/1993`
- ✘ «Según el artículo 3 del Reglamento de Armas, aprobado por el Real Decreto 137/1993, de 29 de enero, las armas de la categoría…» (cita en vez de explicar, demasiado larga)
- ✘ «Es la E, como todo el mundo sabe.» (no explica nada)

## Temas sin artículo (tema 1 y parte del 7)

Mecánica de las armas, seguridad en la tenencia y limpieza, historia, calibres y munición no siempre tienen un artículo detrás. Se explica con conocimiento técnico general, sin inventar normas: `article: null`, `flags: ["sin_articulo"]`. Si el tema sí tiene base legal (p. ej. medidas de seguridad en el domicilio, definiciones del art. 2), se cita.

## Avisos por cambios en la norma

Cuando la respuesta oficial (cuestionario de nov-2020) **choca con la norma vigente** (reformas RD 726/2020 y RD 653/2023, o cambios en la LO 4/2015 u otras):

- `flags`: `["discrepancia_reforma_2023"]` (o `_2020`, o `discrepancia_norma` si es otra).
- `notice`: **«Ojo: el cuestionario da por buena X. Tras la reforma de 2023, el art. N dice Z.»** Breve, neutro y verificable en el corpus.
- La `explanation` sigue explicando por qué en el examen se espera X.
- `confidence` como mucho «media»: estas las revisa una persona sí o sí.

No es discrepancia que la norma se haya reescrito con otras palabras si el sentido no cambia.

## Confianza y revisión

- `confidence`: **alta** (artículo localizado y explícito, o hecho técnico indiscutible), **media** (interpretación razonable, o artículo que lo cubre de forma indirecta), **baja** (no encuentro base firme; la explicación es provisional).
- `reviewed` siempre `false` al redactar. Solo pasa a `true` tras la revisión humana (spec §3.3.5).
- `review_notes`: lo que debería mirar quien revise (no se publica).

## Proceso

1. Redacción por tema (un agente Opus por tema) con esta guía y el corpus del BOE.
2. **Verificación independiente** por un modelo distinto (Fable, esfuerzo medio), sin ver el razonamiento del primero: artículo correcto, explicación coherente con la respuesta oficial, cifras exactas, tono, longitud y avisos justificados. Lo que no supere la verificación vuelve a redactarse.
3. Revisión humana: todas las de confianza baja, todos los avisos y una muestra del resto.
