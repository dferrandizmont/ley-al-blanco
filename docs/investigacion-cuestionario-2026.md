# ¿Hay un cuestionario más reciente que el de noviembre de 2020?

Investigación del 22-oct-2026, hecha solo con la web y lectura. Todas las URL se consultaron el **22-oct-2026**, salvo que se indique otra fecha.

## Conclusión

1. **No hay un cuestionario oficial nuevo.** Los 14 PDF que hoy enlaza la Guardia Civil son byte a byte los mismos que descargamos el 18-oct-2026. Coinciden los 14 sha256 y sus `Last-Modified` son de nov./dic. de 2020. La prueba sigue siendo de 20 preguntas, se aprueba con 16 y dura 20 minutos como máximo.
2. **Hay una reforma del Reglamento de Armas en marcha, pero no toca el examen.** El 20-oct-2026 se abrió una audiencia pública, hasta el 28-oct, sobre un proyecto acotado: marcado de armas, punzones y el art. 146 con la multa del 156.j. La reforma de fondo, con la licencia única D+E y un curso obligatorio, solo ha pasado la consulta previa (feb.–mar. 2026) y no tiene texto articulado.
3. **Indicios para el futuro:** si la reforma de fondo sale adelante, hará falta un examen o temario nuevo para la licencia unificada, y quizá un curso previo. Hoy no hay ninguna fecha oficial.

---

## 1. Web de la Guardia Civil (fuente oficial del cuestionario)

### 1.1 Página del programa y del cuestionario
https://web.guardiacivil.es/es/tramites/autorizaciones-de-armas-y-explosivos/controldearmas/pruebas_licenciasarmas/Programa_prueba_teorica_D__E_y_AEM/index.html

- Sigue enlazando los mismos 14 PDF (`/export/sites/guardiaCivil/documentos/iarmas/temarios/temaN_es.pdf` y `temaNr_es.pdf`) y el PDF del programa, que se genera al vuelo desde la página (`/pdflink/.../Programa-de-conocimientos-...-00001.pdf`, sin `Last-Modified`).
- El texto no ha cambiado: «El cuestionario tiene un total de 400 preguntas», 20 por examen, con el reparto 4/3/3/4/3/3/4 por tema. Ese reparto suma 24, el mismo error que ya conocíamos. Además, nuestro extractor encuentra **423** preguntas en los PDF, no 400 (`app/assets/content/armas/GC-2020-11/manifest.json`).
- No hay avisos de novedades ni de reforma. El `Last-Modified` de la página (22-oct-2026) solo refleja que el CMS la regenera; el script de aviso «El contenido puede estar desactualizado» del HTML es una plantilla genérica comentada que no se muestra.

### 1.2 Comparación de los PDF (descargados el 22-oct-2026 a una carpeta temporal ya borrada)

| fichero | sha256 del 22-oct-2026 | ¿igual al del 18-oct? | Last-Modified (servidor) |
|---|---|---|---|
| tema1_es.pdf | f0cf53b1…07c2a9 | sí | 04-nov-2020 11:33:54 GMT |
| tema1r_es.pdf | 092efb3f…50e9a | sí | 04-nov-2020 11:32:11 GMT |
| tema2_es.pdf | 71184843…4e12 | sí | **11-dic-2020** 11:53:41 GMT |
| tema2r_es.pdf | 72add823…e975 | sí | **11-dic-2020** 11:54:01 GMT |
| tema3_es.pdf | 430d7a83…f5c3 | sí | 04-nov-2020 11:33:55 GMT |
| tema3r_es.pdf | 86a2f3c2…acd9 | sí | 04-nov-2020 11:32:12 GMT |
| tema4_es.pdf | 5ea6df65…e45e | sí | 04-nov-2020 11:33:55 GMT |
| tema4r_es.pdf | 5bd9055c…4ecb | sí | 04-nov-2020 11:32:13 GMT |
| tema5_es.pdf | dbd397e4…dec3 | sí | 04-nov-2020 11:33:55 GMT |
| tema5r_es.pdf | 188e13e6…e641 | sí | 04-nov-2020 11:32:13 GMT |
| tema6_es.pdf | 7429f6b7…3360 | sí | 04-nov-2020 11:33:56 GMT |
| tema6r_es.pdf | b2c3567a…3128 | sí | 04-nov-2020 11:32:14 GMT |
| tema7_es.pdf | f21c6af5…9d50 | sí | 04-nov-2020 11:33:56 GMT |
| tema7r_es.pdf | 2ae987ea…be623 | sí | 04-nov-2020 11:32:14 GMT |

Los hashes completos de referencia están en `tool/content/reports/GC-2020-11.md`. El tema 2 se volvió a subir el 11-dic-2020, pero el fichero es el mismo que tenemos. Para la edición `GC-2020-11` no cambia nada.

### 1.3 Página de detalle de las pruebas D, E y AEM
https://web.guardiacivil.es/es/tramites/autorizaciones-de-armas-y-explosivos/controldearmas/pruebas_licenciasarmas/licenciasDEAEM/index.html

- Lo dice textualmente: «al menos a 16 de las 20 preguntas», «con un tiempo máximo para contestar de 20 minutos».
  - **Novedad para la spec:** §2 dice que el tiempo «no consta en el BOE» y que solo lo dan terceros. No consta en el BOE, pero la **Guardia Civil sí lo publica**. Se puede citar como fuente oficial.
- Dice también: 3 convocatorias por solicitud, 6 meses para la práctica una vez aprobada la teórica, y las fechas de examen de 2026 por provincias.
- Normativa que cita: la Orden de 18-3-1998, la Orden de 7-3-2000 y la Resolución de 19-10-1998. En otro párrafo escribe por error «Resolución de 19 de octubre de 1999».
- Página madre, sin cambios ni anuncios: https://web.guardiacivil.es/es/tramites/autorizaciones-de-armas-y-explosivos/controldearmas/pruebas_licenciasarmas/

## 2. BOE: normas que regulan la prueba

| Norma | Estado en el BOE (22-oct-2026) |
|---|---|
| Orden de 18-3-1998, pruebas de capacitación ([BOE-A-1998-7416](https://www.boe.es/buscar/act.php?id=BOE-A-1998-7416)) | Vigente. Última actualización publicada el **10/03/2000**: la Orden de 7-3-2000 modificó el apartado 4. Ningún cambio posterior. |
| Resolución DGGC de 19-10-1998 ([BOE-A-1998-27988](https://www.boe.es/buscar/act.php?id=BOE-A-1998-27988)) | Vigente. Última actualización publicada el **04/12/1998**, es decir, nunca se ha modificado. Sigue diciendo: «un conjunto de 20 preguntas… de tipo test, con tres respuestas» y «al menos 16 de las 20». |
| Reglamento de Armas, RD 137/1993 ([BOE-A-1993-6202](https://www.boe.es/buscar/act.php?id=BOE-A-1993-6202)) | Última actualización del consolidado publicada el 04/04/2025. Cambios desde 2017: Orden INT/1008/2017 (art. 5.1); RD 726/2020; STS de 4-4-2022, que anula el art. 9.1 en la redacción de 2020; RD 653/2023 (art. 9.1 y 4.b). Normas que lo desarrollan: Resolución de 27-11-2024 sobre almacenamiento de armas en el transporte ([BOE-A-2025-386](https://www.boe.es/buscar/doc.php?id=BOE-A-2025-386)) y Resolución de 4-12-2024 sobre cajas fuertes y armeros en domicilios, art. 144.1.a ([BOE-A-2025-387](https://www.boe.es/buscar/doc.php?id=BOE-A-2025-387)). |

No he encontrado en el BOE ninguna orden ni resolución de 2023 a 2026 sobre las pruebas de capacitación D, E y AEM. La única de 2026 que sale al buscar es la Orden INT/25/2026 ([BOE-A-2026-1681](https://boe.es/boe/dias/2026/01/24/pdfs/BOE-A-2026-1681.pdf)), que trata de los instructores de tiro de seguridad privada y no afecta a esta prueba.

> Nota para el contenido: la spec (§3.1) cita las reformas de 2020 y 2023, pero **no** las dos resoluciones de diciembre de 2024 sobre custodia y transporte. Pueden afectar a explicaciones o avisos del tema 1 («medidas de seguridad en la tenencia») y del tema 3 (circulación). Conviene revisarlas.

## 3. Reforma del Reglamento de Armas: dos expedientes distintos

### 3.1 Reforma de fondo: solo consulta pública previa (feb.–mar. 2026)
- Listado de Interior: https://www.interior.gob.es/opencms/es/servicios-al-ciudadano/participacion-ciudadana/participacion-publica-en-proyectos-normativos/consulta-publica-previa/
- Documento: https://www.interior.gob.es/opencms/pdf/servicios-al-ciudadano/participacion-ciudadana/Participacion-publica-en-proyectos-normativos/Consulta-publica-previa/02_2026_consulta_publica_Modificacion_Reglamento_Armas.pdf. Es de la Jefatura de Armas, Explosivos y Seguridad, está firmado el 08/02/2026 y el plazo fue del 16-feb al 8-mar-2026.
- Lo que anuncia, sin articulado:
  - **Curso formativo previo obligatorio**, «desarrollado por el Ministerio del Interior», para las licencias de defensa personal, caza, tiro deportivo y seguridad privada.
  - **Unificación de D y E** en una sola licencia de caza (según Interior, unos 80.000 expedientes menos al año), con un **límite al número de rifles** y respetando los derechos de quien ya tiene licencia.
  - Las armas de las categorías 2ª.2 y 3ª.1 se podrían usar tanto para caza como para tiro deportivo, y el calibre .22 para caza.
  - La licencia F de 3ª clase quedaría limitada al .22, y habría más armas para los tiradores de 1ª.
  - Controles sobre machetes y «armas tácticas».
  - Informe psicofísico cada 3 años a partir de los 67 para la licencia F.
- **Estado:** no hay texto articulado público. No he encontrado audiencia pública, dictamen del Consejo de Estado ni nada en el BOE de este expediente. La consulta no dice nada concreto sobre el contenido del examen teórico.

### 3.2 Reforma acotada: audiencia pública ABIERTA del 20 al 28-oct-2026 (tramitación urgente)
- Listado: https://www.interior.gob.es/opencms/es/servicios-al-ciudadano/participacion-ciudadana/participacion-publica-en-proyectos-normativos/audiencia-e-informacion-publica/
  - Nota aclaratoria de Interior: este proyecto «no tiene relación» con la consulta previa de febrero-marzo de 2026.
- Texto del proyecto: https://www.interior.gob.es/opencms/pdf/servicios-al-ciudadano/participacion-ciudadana/Participacion-publica-en-proyectos-normativos/Audiencia-e-informacion-publica/15_2026_Proyecto_Modificacion_Reglamento_Armas.pdf (Last-Modified 19-oct-2026).
- Memoria (MAIN): https://www.interior.gob.es/opencms/pdf/servicios-al-ciudadano/participacion-ciudadana/Participacion-publica-en-proyectos-normativos/Audiencia-e-informacion-publica/15_2026_Memoria_Modificacion_Reglamento_Armas.pdf
  - Va por tramitación urgente, por eso no hubo consulta previa.
  - Tiene pendientes el informe de la CIPAE, el de la SGT, el de la Oficina de Coordinación y el dictamen del Consejo de Estado.
  - La fecha del acuerdo del Consejo de Ministros que autoriza la urgencia aparece como «13 de octubre de 2016». Seguramente es una errata por 2026.
- Contenido, un artículo único de 5 apartados. Responde a la carta de emplazamiento de la Comisión Europea del 21-11-2025 sobre la Directiva (UE) 2021/555.
  1. Disposición final 4ª del RD 137/1993: título competencial.
  2. **Art. 28.10, marcado:** solo quedan exentas las armas antiguas (6ª.2) y las declaradas históricas, con certificado de la Intervención Central. Las artísticas sin marcado se marcarán. Desaparece la exención de las armas de colección y de sistema Flobert.
  3. **Art. 30, punzones:** se prohíbe vender, adquirir, poseer o usar armas sin los punzones de un banco oficial. Solo quedan exentas las antiguas y las históricas.
  4. **Art. 146.2 y 146.3:** el porte o uso de armas en establecimientos públicos y lugares de reunión se considera ilícito, con referencia a la LO 4/2015. Además, las autoridades podrán poner «carteles de advertencia normalizados».
  5. **Art. 156.j:** la infracción incluye ahora contravenir el art. 146. La multa sigue siendo de 300,51 a 601,01 €.
- **No toca** las licencias D y E, las pruebas de capacitación ni el curso. Entra en vigor al día siguiente de publicarse en el BOE, cuando se publique.

### 3.3 Otros trámites de 2026 de este año
- Orden ministerial con las instrucciones para aplicar el Reglamento de Armas en la Guardia Civil (audiencia pública cerrada el 18-sep-2026; `11_2026_Proyecto_OM_Aplicacion_Reglamento_Armas_personal_GC.pdf`). Se refiere a las armas del personal del Cuerpo, no a las licencias de particulares.

## 4. Qué dicen terceros (no oficial; solo como indicio)

| Fuente | Qué dice | Valoración |
|---|---|---|
| [licenciaf.com/nuevo-reglamento-de-armas](https://licenciaf.com/nuevo-reglamento-de-armas/) (nota «a fecha de 6 de octubre de 2026») | Dice que no hay texto articulado ni fecha de entrada en vigor y que «el examen de hoy no ha cambiado». | Coincide con las fuentes oficiales. |
| [Libertad Digital, 23-feb-2026](https://www.libertaddigital.com/espana/2026-02-23/rifles-limitados-y-curso-obligatorio-los-cazadores-en-alerta-por-la-reforma-que-impulsa-marlaska-7361812/), [Newtral, 20-feb-2026](https://www.newtral.es/armas-interior-reglamento-directiva-comision/20260220/), [Jara y Sedal](https://revistajaraysedal.es/reforma-reglamento-armas-limite-rifles-cazadores/), [Club Caza](https://www.club-caza.com/article/art/34910), [armas.es](https://www.armas.es/espana-prepara-una-reforma-profunda-del-reglamento-de-armas-analisis-completo-del-borrador-y-todas-sus-implicaciones) | Cuentan la consulta de febrero: curso obligatorio, licencia D+E, límite de rifles. Jara y Sedal especula con que todos los cazadores tendrían que tener armero. | Prensa y sector; lo del armero no está en ningún texto oficial. No he podido abrir Newtral (403). |
| [cazatest.es, 12-feb-2026](https://cazatest.es/blog/que-preguntan-examen-licencia-armas-2026) | Habla de preguntas «actualizadas 2026», 30 minutos, **15/20** para aprobar y que cada error resta 0,33. | **Contradice** a la Guardia Civil y al BOE (16/20, 20 minutos, sin penalización). No es fiable. |
| [yurkap.com](https://yurkap.com/test-permiso-de-armas) y otras webs de test | Ponen «2026» en el título, pero usan el banco de la Guardia Civil de 2020 (hablan de 400 o 423 preguntas). | Es marketing; no hay ningún banco nuevo. |

No he encontrado ninguna academia, federación, foro ni app que muestre preguntas oficiales nuevas o un PDF de la Guardia Civil posterior a 2020.

## 5. Impacto en la app

- **Banco de preguntas:** ninguno. La edición `GC-2020-11` sigue siendo la vigente, y el checksum del manifiesto sigue sirviendo.
- **Spec y textos:**
  - Se puede citar el límite de 20 minutos como dato oficial de la Guardia Civil (página `licenciasDEAEM`), no solo de terceros.
  - Conviene explicar la diferencia entre 400 y 423 preguntas («la web dice 400; los PDF contienen 423») si mostramos el total.
- **Si se aprueba la reforma acotada del §3.2,** habrá avisos (`flag`) en las preguntas que tocan:
  - Art. 146 y su sanción (posibles: t5-043, t5-044, t5-047, t5-064, t5-052, t5-062).
  - Punzones y exenciones (t6-017 a t6-020, t6-051, t6-058, t2-007, t7-002).
  - Marcado de las armas de colección, Flobert y artísticas (t1-023, t2-007, t7-003).

  Estos ID salen de una búsqueda por palabras clave en `questions.json` y hay que revisarlos a mano. **La respuesta oficial no se cambia**: solo se añade el aviso, citando el RD y su fecha en el BOE.
- **Si se aprueba la reforma de fondo del §3.1** (licencia única D+E, curso previo), lo previsible es que:
  - Cambie la denominación «licencias D y E» en el nombre, la ficha de la tienda y la ASO.
  - La Guardia Civil publique un programa o cuestionario nuevo, por lo que habría que crear una edición nueva del contenido.
  - Haya que añadir un aviso sobre el curso obligatorio.

  La arquitectura actual (contenido por ediciones, con versión y checksum) ya permite añadir la edición nueva sin tocar el código.

## 6. Recomendación

1. **Mantener `GC-2020-11`** como banco vigente y seguir mostrando la fecha de la fuente y la de revisión. Hoy no hay motivo para avisar al usuario de un cuestionario nuevo.
2. **Antes de cada versión, vigilar:**
   - Los 14 sha256 y el texto «400 preguntas / 20 / 16 / 20 minutos» de las dos páginas de la Guardia Civil.
   - El listado de audiencia pública de Interior.
   - El consolidado del RD 137/1993 en el BOE (fecha de «Última actualización»).

   Conviene automatizarlo en `tool/content`, con un script que compare hashes y fechas.
3. **Apuntar en el seguimiento** el proyecto 15/2026 (audiencia abierta hasta el 28-oct-2026, tramitación urgente). En cuanto se publique en el BOE:
   - Añadir avisos a las preguntas de marcado, punzones y art. 146 y 156.j.
   - Actualizar las explicaciones con el artículo nuevo.
4. **Revisar las explicaciones de los temas 1 y 3** contra las Resoluciones de 27-11-2024 y 4-12-2024 (transporte y armeros). Hoy no están en la spec.
5. **No anunciar en la app ni en la tienda** la «licencia única» ni el «curso obligatorio» hasta que haya un texto en el BOE. Como mucho, poner en Ajustes o en la ayuda una nota neutral: «Interior estudia una reforma; el examen actual no ha cambiado (fuentes y fecha)».
