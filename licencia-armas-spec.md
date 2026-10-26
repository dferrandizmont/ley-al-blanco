# App de test de la licencia de armas (especificación de producto)

18 oct 2026 · Especificación de una app gratuita de preparación del examen, basada en el cuestionario de la Guardia Civil y la normativa del BOE.

> **Nombre:** «Ley al Blanco» (decidido el 23-oct-2026). **No usar «oficial» ni «Guardia Civil»** en el nombre, el icono ni las capturas.

---

## 1. Resumen

App para aprobar a la primera el examen teórico de la licencia de armas D, E y la autorización para menores (AEM). Reutiliza el motor de test diseñado para el CCSE: práctica por tema, simulacros, repetición espaciada y explicaciones.

**Promesa:**
> **Las ~400 preguntas del cuestionario publicado, explicadas con su artículo del Reglamento. Gratis y de código abierto, sin anuncios.**

**Por qué:**
- El banco de preguntas es público: la Guardia Civil lo declara «de dominio público de los aspirantes».
- La líder de iOS (4.300 valoraciones) está abandonada desde 2018, y las de Android tienen 3,8★ o son caras.
- El 40 % de las quejas son por pagos confusos y el 20 % por anuncios.

**Esfuerzo:** 1–2 semanas si el motor del CCSE ya existe. Se distribuye gratuitamente; no hay un objetivo de ingresos por compras.

---

## 2. El examen (lo que hay que imitar)

| | Dato | Fuente |
|---|---|---|
| Quién lo hace | Tribunal de la Comandancia de la Guardia Civil (Intervención de Armas) | Resolución de 19-oct-1998, BOE-A-1998-27988 |
| Prueba teórica | **20 preguntas tipo test de 3 opciones; se aprueba con 16** | Ídem |
| De dónde salen | Del cuestionario publicado, con 7 temas | Web de la Guardia Civil |
| Tiempo | **No consta en el BOE.** Fuentes de terceros hablan de 20 minutos. | Usar un cronómetro opcional marcado como «orientativo» |
| Convocatorias | 3 por solicitud, con 3 meses como máximo entre ellas; la teórica aprobada vale 6 meses | Resolución de 1998 |
| Prueba práctica | Rifle: 5 disparos a 25 m con al menos 1 impacto. Escopeta: 2 disparos. Se valoran la seguridad y el manejo. | Anexo II de la Resolución |
| Tasa | 95,58 € (o 70 € si el campo de tiro no corre a cargo de la Guardia Civil) | Ministerio del Interior, página de tasas |

**Temas:** 1. Funcionamiento y seguridad · 2. Categorías de armas · 3. Circulación, revista y transferencia · 4. Documentación y licencias, Tarjeta Europea · 5. Régimen sancionador · 6. Reparación, prueba y depósito · 7. Armas de colección, definiciones, historia, calibres y munición.

**Reparto por tema:** la web indica 4/3/3/4/3/3/4, que **suma 24, no 20** (error de la propia web). En la app: el simulacro reparte las 20 preguntas en proporción al tamaño de cada tema, con un ajuste configurable desde los datos.

---

## 3. Contenido: de dónde sale y cómo se prepara

### 3.1 Fuentes
| Contenido | Fuente | Uso |
|---|---|---|
| **Preguntas y respuestas** | PDF por tema en la web de la Guardia Civil: `…/documentos/iarmas/temarios/tema1_es.pdf` … `tema7_es.pdf`, y las respuestas en `tema1r_es.pdf` … `tema7r_es.pdf`. Son unas 420 preguntas; los PDF son de noviembre de 2020. | Banco principal, **citando la fuente y la fecha** |
| **Normativa** | Reglamento de Armas (RD 137/1993), con las reformas de 2020 (RD 726/2020) y 2023 (RD 653/2023). Texto consolidado en el BOE. | Explicaciones y referencias a artículos. Las leyes no tienen derechos de autor (art. 13 de la Ley de Propiedad Intelectual) |
| **Formato del examen** | Resolución de 19-oct-1998 y Orden de 18-mar-1998 (BOE) | Simulacro y sección de la prueba práctica |
| **Explicaciones y resúmenes** | **Redacción propia** | Valor diferencial y contenido con derechos propios |

### 3.2 Reglas legales (no es asesoramiento jurídico)
- Reutilizar el cuestionario **citando la fuente y la fecha** y **sin alterar su sentido** (Ley 37/2007 de reutilización de la información del sector público).
- Texto fijo en Ajustes y en la ficha: «App independiente y no oficial. Preguntas basadas en el cuestionario publicado por la Dirección General de la Guardia Civil (enlace, consultado el dd/mm/aaaa)».
- **No** usar logos ni el escudo. **No** copiar explicaciones de academias, blogs ni de la competencia.
- **Enviar un correo a la Intervención Central de Armas** pidiendo confirmación de que se puede reutilizar. Es barato y da tranquilidad.

### 3.3 Proceso de preparación del contenido
1. **Descargar** los 14 PDF y guardar la fecha y el checksum de cada uno.
2. **Extraer** el texto (`pdftotext -layout` o pdfplumber) con un script que separe el número de pregunta, el enunciado, las 3 opciones y la respuesta correcta (del PDF de respuestas).
3. **Validar** con un script:
   - Exactamente 3 opciones y 1 respuesta correcta.
   - Numeración continua y sin duplicados.
   - Número de preguntas por tema igual al del PDF.
4. **Revisar contra la normativa vigente:** marcar las preguntas cuya respuesta pueda haber cambiado con las reformas de 2020 y 2023. Las reseñas dicen que hay discrepancias. Si las hay, **no cambiar la respuesta oficial**: mostrar un aviso del tipo «Ojo: el cuestionario dice X; tras la reforma de 2023 el artículo Y dice Z».
5. **Escribir las explicaciones:**
   - Un borrador de 1–2 frases por pregunta, hecho a partir del artículo correspondiente del Reglamento.
   - **Revisión humana del 100 %**: un error aquí hunde la nota en las reseñas.
   - Campo `article` con el artículo citado (p. ej. «Art. 3 RD 137/1993»).
6. **Escribir los resúmenes por tema:** 1 página por tema con tablas (categorías de armas, licencias y vigencias, sanciones).
7. **Detección de cambios:** el script comprueba cada mes si los PDF de la Guardia Civil han cambiado (checksum) y avisa para actualizar el banco.

### 3.4 Formato (el mismo esquema del CCSE)
```json
{
  "id": "t2-017",
  "tema": 2,
  "type": "mc3",
  "stem": "…enunciado tal cual del cuestionario…",
  "options": ["…", "…", "…"],
  "answer": 1,
  "explanation": {"es": "Explicación propia en 1-2 frases."},
  "article": "Art. 3 RD 137/1993",
  "notice": {"es": "Ojo: el cuestionario dice X; tras la reforma de 2023 el art. Y dice Z."},
  "source": {"doc": "tema2_es.pdf", "retrieved": "2026-10-18", "sha256": "…"},
  "flags": ["discrepancia_reforma_2023"],
  "edition": "GC-2020-11",
  "reviewed": true
}
```

---

## 4. Alcance

### P0 (MVP)
1. **Banco completo** (~420 preguntas) con su versión y fecha visibles («Cuestionario GC nov-2020 · revisado el 18-oct-2026»).
2. **Práctica por tema**, con respuesta al momento y **explicación + artículo**.
3. **Simulacro real:** 20 preguntas con reparto por tema, aprobado con 16, cronómetro opcional, revisión al final.
4. **Repaso de fallos** que reúna los errores de **todos** los modos (es una queja concreta contra la competencia).
5. **Repetición espaciada** y **«probabilidad de aprobar»**. Como el examen sale de un banco cerrado, la probabilidad se calcula simulando miles de exámenes con el dominio que tiene el usuario de cada pregunta.
6. **Gratis y de código abierto (decisión del dueño, 26-oct-2026):** los siete temas, teoría, simulacros ilimitados, cifras y tarjetas están abiertos para todos. Sin compras, anuncios, suscripción ni servicios de terceros.
7. Sin conexión, sin cuenta, modo oscuro y textos grandes.

### P1
- Resúmenes de teoría por tema y glosario (categorías 1.ª a 7.ª, tipos de licencia).
- Sección **«La prueba práctica»**: protocolo de seguridad, qué se valora, errores que te eliminan. Solo texto y diagramas, sin imágenes de armas apuntando.
- Pestaña AEM (requisitos para menores).
- Exportar e importar el progreso a un archivo.

### P2
- «Pack Cazador»: exámenes de aptitud para la licencia de caza por comunidad autónoma (cada uno con su fuente y licencia; es otro proyecto).
- Avisos de la reforma del Reglamento.

---

## 5. Diseño

### Principios
- **Seria y de fiar, no agresiva.** El público es variado (cazadores de 50–70 años, tiradores deportivos, jóvenes con la AEM). Ni estética militar ni de videojuego.
- **Leer cómodo:** enunciado de 18–20 pt, opciones como tarjetas grandes a todo el ancho, mucho espacio.
- **Confianza visible:** en cada explicación, una ficha con el artículo («Art. 96 Reglamento») y, en Ajustes, la fuente y la fecha del banco.

### Sistema visual
- **Paleta:**
  - Verde monte `#2F5D50` (color principal).
  - Arena `#EFE9DD` (fondo claro).
  - Naranja de seguridad `#F27A1A` (acento y llamadas a la acción: es el color de los chalecos de caza).
  - Correcto `#2E9E5B`, incorrecto `#D64545`, **siempre con icono ✓/✗**, no solo color.
  - En modo oscuro: fondo `#141A17` y verde aclarado.
- **Tipografía:** Inter o la del sistema; números tabulares en las puntuaciones.
- **Icono de la app:** un escudo redondeado en verde monte con un **«16/20»** o un ✓ en naranja. **Sin dibujo de arma** (evita problemas de revisión y queda más limpio).
- **Ilustraciones:** líneas sencillas (diana, documento, candado de seguridad), nunca un arma apuntando a una persona (norma de capturas de Apple).

### Pantallas
1. **Inicio:**
   - Un anillo grande con la **probabilidad de aprobar**.
   - Debajo, «Continuar» (repaso del día) y las 7 tarjetas de tema con su barra de dominio.
   - Acceso a Simulacro y a Fallos.
2. **Pregunta:**
   - Enunciado, 3 tarjetas de opción, barra de progreso arriba.
   - Al responder: la tarjeta se colorea con ✓/✗ y sube una hoja con la **explicación + la ficha del artículo** y el botón «Siguiente».
3. **Simulacro:** cronómetro opcional, navegador de las 20 preguntas, entregar. Resultado: APTO o NO APTO en grande, aciertos por tema y revisión de fallos.
4. **Fallos:** lista filtrable por tema; «Repasar todos».
5. **Teoría (P1):** resúmenes con tablas desplegables.
6. **Ajustes:** fuente y fecha del banco, aviso legal, licencias de código abierto, contacto (con respuesta prometida en menos de 48 h).

### Acceso
Todo el contenido está disponible desde la instalación, sin candados ni ofertas.

---

## 6. Arquitectura

Pila: **Flutter + Riverpod + go_router + Drift**, sin servidor.

| Pieza | Detalle |
|---|---|
| Contenido | `assets/content/armas/<edición>/questions.json`, con checksum comprobado al importarlo |
| Actualizaciones de contenido | Incluidas en nuevas versiones de la app; sin descargas desde la app |
| Tablas | `questions`, `attempts`, `srs_state`, `mocks`, `settings` (las mismas del CCSE) |
| Generador de simulacros | Reparto configurable por tema; evita repetir preguntas de los 2 últimos simulacros |
| Probabilidad de aprobar | Simulación con el dominio de cada pregunta (más de 10.000 exámenes simulados en el móvil, menos de 100 ms) |
| Errores | Manejo local; sin telemetría ni envío de informes |

**Pruebas:** el reparto del simulacro, la puntuación (16/20), la importación sin duplicados, el acceso completo desde una instalación nueva y la prueba en un iPhone SE (las reseñas hablan de opciones que no se podían pulsar en pantallas pequeñas).

---

## 7. Distribución gratuita y código abierto

Decisión del dueño del **26-oct-2026**, que sustituye cualquier propuesta anterior de pago:
- App 100 % gratuita en Google Play, App Store y GitHub Releases (F-Droid descartado por el dueño el 26-oct-2026).
- Los siete temas, toda la teoría, cifras, tarjetas, repaso y simulacros ilimitados abiertos para todos.
- Sin compras, suscripciones, anuncios ni servicios de terceros. Nada se envía desde la app.
- Código [MIT](LICENSE); contenido propio [CC BY-SA 4.0](LICENSE-CONTENT.md). La atribución del cuestionario de la Guardia Civil se conserva; no está cubierto por esas licencias.
- Sin dependencias privativas (sin SDK de terceros).

## 8. ASO

- **Título:** «Licencia de Armas: Test D y E» (no se puede usar «oficial»).
- **Subtítulo:** «Examen Guardia Civil explicado». Ojo: antes de usar «Guardia Civil» en el subtítulo, comprobar que se acepta como descripción y no como marca. Si hay duda: «Examen teórico explicado».
- **Palabras clave:** licencia armas, examen armas, test licencia, licencia E, licencia D, AEM, permiso armas, caza, tiro, escopeta, rifle
- **Capturas:**
  1. «Las ~400 preguntas, explicadas».
  2. «Simulacro real: 20 preguntas, apto con 16».
  3. «Tu probabilidad de aprobar».
  4. «Repasa tus fallos».
  5. «Gratis. Sin anuncios.»
- **Clasificación por edades:** 12+ en iOS y PEGI 12 en Google Play.
- **Política de Google Play:** declarar que la app no es gubernamental. No enlazar armerías ni tiendas.

## 9. Calendario

| Día | Entregable |
|---|---|
| 1–2 | Script de extracción y validación de los 14 PDF → JSON |
| 3–5 | Explicaciones (borrador + revisión) de los temas 1–3 |
| 6–7 | Explicaciones de los temas 4–7 + marcar discrepancias con la reforma de 2023 |
| 8–9 | Motor del CCSE con el nuevo contenido + simulacro de 20/16 + acceso completo |
| 10 | Diseño (paleta, icono), capturas, ficha |
| 11–12 | Pruebas en dispositivos pequeños y grandes + envío a Google Play y App Store |

## 10. Riesgos

| Riesgo | Cómo mitigarlo |
|---|---|
| **Reforma del Reglamento** (consulta pública feb–mar 2026; curso obligatorio y unificación de las licencias D y E) en 12–24 meses | Contenido como datos versionados; «actualizaciones incluidas»; publicar la v2 pronto cuando salga (será una ventaja frente a las apps abandonadas) |
| Respuestas desfasadas del banco de 2020 | Revisión contra el Reglamento vigente y avisos en las preguntas afectadas |
| Apps nuevas con explicaciones (LicenArmas, ArmasTest, octubre 2026) | Calidad de las explicaciones, la probabilidad de aprobar, el acceso gratuito y conseguir las primeras 50 reseñas pronto |
| Rechazo en la revisión de las tiendas | Sin imágenes de armas, sin enlaces de compra, aviso de app no oficial |
| Mercado pequeño | Coste de construcción bajo; reutilizar para el «Pack Cazador» |

## 11. Decisiones pendientes

- [x] Nombre definitivo: Ley al Blanco.
- [ ] Enviar el correo a la Guardia Civil para confirmar la reutilización (antes de publicar).
- [ ] ¿Incluir ya la AEM o dejarla para la v1.1?
- [x] Gratis en todas las plataformas (decisión del dueño: 26-oct-2026).
