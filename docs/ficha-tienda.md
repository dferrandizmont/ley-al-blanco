# Ficha de tienda — Ley al Blanco

Textos para Google Play y App Store de una app **gratuita y de código abierto**: sin compras, sin anuncios, sin cuentas y sin servicios de terceros. Todo el contenido está abierto para todo el mundo.

Los recuentos incluyen espacios, signos de puntuación y saltos de línea internos (un carácter por salto, LF), sin salto final; el Markdown de este documento no forma parte del texto que se copiará a las tiendas.

Las respuestas para los formularios de Play Console se preparan aparte, junto a este documento.

## 1. Título y descripción corta

### Google Play

- **Título:** `Ley al Blanco: armas D y E` (**26 caracteres**; máximo 30).
- **Descripción breve:** `Gratis, sin anuncios y sin conexión, con cada respuesta explicada.` (**66 caracteres**; máximo 80).

### App Store

- **Nombre:** `Ley al Blanco` (**13 caracteres**; máximo 30).
- **Subtítulo:** `Examen D, E y AEM explicado` (**27 caracteres**; máximo 30).

## 2. Descripción larga para Google Play y App Store

```text
Ley al Blanco te ayuda a preparar la prueba teórica de las licencias D y E y de la autorización especial para menores (AEM) con el cuestionario publicado y explicaciones propias.

Es una app gratuita y de código abierto, sin anuncios, sin cuentas y sin servicios de terceros. Todo el contenido se consulta sin conexión.

Cada pregunta incluye una explicación de redacción propia y, cuando corresponde, una referencia normativa. Las preguntas con discrepancias normativas identificadas incluyen un aviso. Estos avisos forman parte del contenido de la app; no son alertas automáticas de nuevas reformas.

QUÉ INCLUYE
• Los 7 temas completos, con preguntas y resúmenes de teoría.
• Simulacros ilimitados de 20 preguntas, que puedes retomar y revisar.
• Lecturas sobre la prueba práctica y la AEM, y glosario.
• Repaso espaciado, ficha de fallos y buscador de todo el banco.
• Pregunta del día de cualquiera de los 7 temas, con racha.
• Cifras y plazos y todas sus tarjetas.

FUNCIONES PARA REPASAR
• Simulacro de 20 preguntas: apto desde 16 aciertos, con preguntas marcadas como dudosas y un mapa para navegar entre ellas.
• Estimación de tu probabilidad de aprobar según tu progreso, sin garantía de resultado.
• Fichas de fallos con la última respuesta fallada, explicación y accesos para repasar.
• Tarjetas de cifras para pensar la respuesta y darle la vuelta a la tarjeta.
• Modo oscuro y exportación e importación del progreso mediante un archivo.

SIN COSTE Y DE CÓDIGO ABIERTO
Todo lo anterior está abierto para todo el mundo: sin compras, sin suscripciones y sin anuncios. El código de la app se publica con licencia libre y el contenido propio con Creative Commons.

PRIVACIDAD
No necesitas una cuenta. El progreso y los ajustes se guardan en el dispositivo, sin sincronización. La app no envía datos ni informes de errores y no usa servicios de terceros. Puedes exportar tu progreso y elegir dónde guardarlo; las copias del sistema operativo dependen de tu configuración. Soporte: dev@mainshai.com.

App independiente y no oficial. Preguntas basadas en el cuestionario publicado por la Dirección General de la Guardia Civil (consultado el 18/10/2026). Las explicaciones son de redacción propia y no constituyen asesoramiento jurídico.
```

**Longitud:** **2.248 caracteres** (máximo 4.000).

## 3. Palabras clave de App Store

```text
licencia,armas,test,simulacros,preguntas,caza,tiro,escopeta,reglamento,repaso,teoria,practica,cifras
```

**Longitud:** **100 caracteres** (100 exactos; 100 bytes ASCII). Se omiten tildes para mantener el límite de bytes y no se repiten términos del nombre ni del subtítulo.

### Búsquedas objetivo

- `licencia de armas` (**17 caracteres**).
- `examen de armas` (**15 caracteres**).
- `test licencia armas` (**19 caracteres**).
- `examen licencia D` (**17 caracteres**).
- `examen licencia E` (**17 caracteres**).
- `simulacro licencia armas` (**24 caracteres**).
- `examen AEM` (**10 caracteres**).
- `prueba teórica licencia armas` (**29 caracteres**).
- `preguntas examen armas` (**22 caracteres**).
- `test licencia D y E` (**19 caracteres**).

## 4. Capturas

### 4.1. Capturas que genera el script

`cd app && flutter test --tags store --run-skipped test/store` deja en `app/build/store/play/` seis PNG de **1080 × 1920** (Google Play, móvil 9:16). Los títulos van dentro de la imagen y están definidos en `app/test/store/store_screenshots_test.dart` (el `LEEME` de `tool/store/` explica cómo cambiarlos).

| Fichero | Título en la imagen | Pantalla |
|---|---|---|
| `01-preguntas-explicadas.png` | «Las 423 preguntas, explicadas» (subtítulo «Con su artículo del BOE») | Práctica: pregunta respondida con veredicto, explicación y el artículo del Reglamento. |
| `02-simulacro.png` | «Simulacro real: 20 preguntas, apto con 16» | Resultado de un simulacro APTO (18 de 20). |
| `03-probabilidad.png` | «Tu probabilidad de aprobar» | Inicio con el anillo de probabilidad y el progreso por temas. |
| `04-fallos.png` | «Repasa tus fallos» | Lista de fallos de los siete temas. |
| `05-gratis.png` | «Gratis. Sin anuncios.» | Lista de Teoría con los siete temas y todos los documentos abiertos. |
| `03-probabilidad-oscuro.png` | «Tu probabilidad de aprobar» (variante en modo oscuro) | La misma pantalla de Inicio en modo oscuro. |

Google Play admite de 2 a 8 capturas de móvil, con el lado corto de al menos 320 px y el largo como máximo 3,6 veces el corto (9:16 cumple). Las seis de arriba están dentro del rango. Para App Store quedan las mismas cinco en `app/build/store/ios63/` (**1206 × 2622**, iPhone con Dynamic Island y pantalla mediana, el tamaño que exige hoy la consola), `ios69/` (1320 × 2868) e `ios65/` (1284 × 2778); la variante oscura es solo de Play. Todos los PNG son **opacos, sin canal alfa**: ni App Store ni Google Play admiten capturas con transparencia, y así no hay que convertirlas a mano antes de subirlas.

### 4.2. Guion ampliado (aún no generado)

Ideas de capturas adicionales, no producidas por el script actual:

| Nº | Pantalla | Titular de la captura |
|---:|---|---|
| 1 | Pregunta con uno de los avisos normativos incluidos en el banco visible. | `Avisos en preguntas afectadas` (**29 caracteres**). |
| 2 | Simulador: navegador de las 20 preguntas con una marcada como dudosa. | `20 preguntas. Apto con 16.` (**26 caracteres**). |
| 3 | Teoría: resúmenes por tema y entradas a las lecturas sobre la prueba práctica, la AEM y el glosario, respetando el encuadre real. | `Teoría, práctica, AEM y glosario` (**32 caracteres**). |
| 4 | Inicio desplazado hasta los accesos separados a Cifras y plazos y Tarjetas de cifras. | `Cifras y plazos, de un vistazo` (**30 caracteres**). |

Ninguna captura debe incluir armas, logotipos, escudos ni «Guardia Civil» como marca. En los textos que se copian a las tiendas, la referencia a la Guardia Civil aparece únicamente como fuente de las preguntas, en la atribución de la descripción larga. Si el pie de Inicio aparece en el encuadre, la atribución a la Guardia Civil y la edición «Cuestionario GC nov-2020» solo se aceptan como referencia de la fuente del cuestionario, nunca como marca de la app. El guion no sustituye la revisión de las imágenes finales: deben mostrar pantallas reales y todo el contenido abierto. Si en el encuadre de Inicio no caben el anillo de probabilidad y la tarjeta de la pregunta del día, elige encuadres distintos.

## 5. Notas de cumplimiento

Estas notas recogen los requisitos que deben comprobarse en las directrices vigentes de cada tienda y cómo afectan al texto de esta ficha.

### Google Play

- **Dangerous Products:** no facilita la compra de armas, munición o accesorios ni da instrucciones de fabricación o modificación. La ficha no enlaza armerías, tiendas de armas ni de munición y no ofrece esas instrucciones.
- **Apps gubernamentales y afirmaciones engañosas:** el texto declara que es una app independiente y no oficial y no sugiere afiliación gubernamental. «Oficial» no se usa como afirmación de identidad; solo aparece dentro de la fórmula «no oficial». En la ficha de Play debe marcarse que **la app no es gubernamental**.
- **Sin anuncios:** no hay SDK de publicidad, ni banners, ni intersticiales, ni ningún código de terceros. En Play Console, «Anuncios» se responde **No** y en «Detalles de la app» la casilla de anuncios queda sin marcar.
- **Sin compras:** la app es gratuita y no hay productos dentro. En Play Console, «¿Gratis o de pago?» es **Gratis** y «Compras dentro de la app» es **No**. No hay contenido bloqueado ni funciones «desbloqueables» que describir.
- **Acceso:** todo el contenido se abre sin cuenta y sin pagar; el formulario «Acceso a la app» no necesita instrucciones para el equipo de revisión.
- **Público objetivo:** 13–15, 16–17 y 18 o más. Sin menores de 13, para no entrar en la política Familiar.
- **Clasificación por edades:** el resultado esperado del cuestionario IARC es **Mayores de 12 / PEGI 12**, coherente con la clasificación que anuncia la política de privacidad. La clasificación definitiva la da el cuestionario de la tienda.

### App Store

- **Directriz 1.1.3:** la app es educativa y trata la normativa y la seguridad; no fomenta el uso ilegal o imprudente de armas ni facilita su compra.
- **Directriz 2.3.8:** las capturas no muestran armas ni ninguna escena en la que un arma apunte a una persona.
- **Directriz 4.3 (apps clonadas o spam):** el contenido propio —explicaciones, teoría, avisos normativos incluidos, estimación de la probabilidad de aprobar y material de repaso— diferencia la app. La ficha no nombra ni compara otras apps o webs.
- **Directriz 5.2 (derechos de terceros):** se cita la fuente y la fecha del cuestionario y no se alteran enunciados, opciones ni respuestas. El aviso de la descripción larga debe conservarse.
- **Comprobación antes de enviar:** el análisis de mercado advierte de que las referencias a las directrices 4.3 y 5.2 deben contrastarse con la versión vigente de las directrices de Apple.
- **Clasificación por edades:** el análisis propone **12+**; confirmar la clasificación aplicable con el cuestionario vigente de App Store Connect.

### Requisitos comunes

- **Atribución:** el cuestionario se reutiliza citando fuente y fecha, conforme a la Ley 37/2007 (de 16 de noviembre, sobre reutilización de la información del sector público); los textos legales que se citan no son objeto de propiedad intelectual (art. 13 de la Ley de Propiedad Intelectual, texto refundido). Antes de publicar hay que actualizar la fecha si cambia el cuestionario y obtener la revisión humana pendiente.
- **Ausencia de marca o imagen institucional:** no se usa «oficial» como afirmación de identidad, ni logos, escudos, nombres de entidades como marca o imágenes de armas en nombre, icono o capturas. «Guardia Civil» solo aparece como fuente de las preguntas.
- **Privacidad:** sin cuentas, analítica ni transmisión de datos desde la app; progreso local, exportación voluntaria y enlaces externos por acción del usuario. Ver [privacy.md](privacy.md).
- **Gratuita y de código abierto:** en todas las plataformas, sin compras dentro de la app, sin suscripción y sin contenido bloqueado. Decisión del dueño, 26-oct-2026.
- **Pendiente antes de publicar:** la descripción dice que el código se publica con licencia libre. Antes de subir la primera versión hay que comprobar que el repositorio público y el fichero `LICENSE` existen y son coherentes con esa frase, y que la licencia del contenido propio está identificada. Si eso no está listo, se quita ese párrafo de la descripción larga.

### Estado editorial

- El texto evita comparaciones y nombres de competidores.
- La revisión jurídica, de privacidad y de la clasificación por edades corresponde a una persona antes de publicar.
- La fecha de consulta del cuestionario indicada en el borrador es la del contenido documentado; hay que verificarla al preparar cada versión publicada.
- El banco de esta rama contiene 423 preguntas con explicación, 55 sin artículo y 12 con aviso; todas siguen con `reviewed: false`. No se presenta el contenido como revisado por una persona ni como actualización normativa automática. La descripción larga no cita esa cifra para no tener que corregirla cuando cambie el banco.
- Las capturas definitivas, los formularios y las pruebas en iOS deben verificarse antes de publicar. La app ya no depende de cuentas de compras ni diagnóstico.
