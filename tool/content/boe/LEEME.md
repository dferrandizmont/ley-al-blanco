# Corpus BOE (legislacion consolidada) para Ley al Blanco

Texto oficial consolidado de las normas en que se apoya el banco `app/assets/content/armas/GC-2020-11/questions.json`.
Las leyes no tienen derechos de autor (art. 13 LPI). Descarga: **2026-10-19**, solo desde boe.es (API de datos abiertos
`https://www.boe.es/datosabiertos/api/legislacion-consolidada/id/{ID}/texto|metadatos` + pagina HTML `act.php?id={ID}`).

- Crudos (datos, no ejecutar): `fuentes/boe/raw/` (`*.texto.xml`, `*.metadatos.xml`, `*.html`, `modificadores/`).
- JSON por norma (generado): `tool/content/boe/<short>.json`. Regenerar: `python -I tool/content/boe/build.py`.
- Buscar: `python -I tool/content/boe/buscar.py "palabras"` (sin acentos, todas las palabras deben aparecer como subcadena;
  `-n 5` limita, `-a` imprime el texto completo, `-r "reglamento-armas:art. 90"` imprime un articulo concreto).

## Normas

| short (json) | Norma | ID BOE | URL | Ultima actualizacion publicada (pagina BOE) | Marca API (`fecha_actualizacion`) | Items | sha256 del `.texto.xml` |
|---|---|---|---|---|---|---|---|
| `reglamento-armas` | RD 137/1993, Reglamento de Armas (con RD 316/2000, 976/2011, 726/2020, 653/2023, Ordenes INT/291/2025 e INT/330/2025, STS 4-4-2022) | BOE-A-1993-6202 | https://www.boe.es/buscar/act.php?id=BOE-A-1993-6202 | 2025-04-04 | 2025-12-17 | 197 (171 arts + 1 bis x2, disp., ITC 1-5 y anexos) | `67744d8fe019bbfaa54a2669d3680c6235de2df1e7d41be8efb2507505edaa81` |
| `lo-4-2015` | LO 4/2015, de proteccion de la seguridad ciudadana | BOE-A-2015-3442 | https://www.boe.es/buscar/act.php?id=BOE-A-2015-3442 | 2021-02-23 (STC 13/2021) | 2025-12-19 | 69 | `ceb57fdb3939cbd0f938258752e5c31a321557cb91d5d5d62eb8e1a40af68c9e` |
| `orden-1998-pruebas` | Orden de 18-3-1998, pruebas de capacitacion para licencias de armas (D, E) | BOE-A-1998-7416 | https://www.boe.es/buscar/act.php?id=BOE-A-1998-7416 | 2000-03-10 | 2025-12-18 | 10 | `3591d5acaca04db724878191f1fa141129248da80692497610d2ac694cb4e6db` |
| `resolucion-1998-pruebas` | Resolucion de 19-10-1998 DGGC, instrucciones para ejecutar la Orden (programa del examen, Anexo I) | BOE-A-1998-27988 | https://www.boe.es/buscar/act.php?id=BOE-A-1998-27988 | 1998-12-04 | 2025-12-18 | 18 | `38477b0881175ee504cd88dc292766f53085c5ec3aedb5d232d39e51698d0f4f` |
| `ley-caza-1970` | Ley 1/1970, de 4 de abril, de caza (solo para el destino de armas retiradas, Reglamento art. 167) | BOE-A-1970-369 | https://www.boe.es/buscar/act.php?id=BOE-A-1970-369 | 2009-12-23 | 2025-12-16 | 60 | `0aa0b5319bd9721826a8c682a6bfb8a68946d19e098e6b14e344c94e0ccb29dd` |
| `lo-1-1992` | LO 1/1992, de proteccion de la seguridad ciudadana (**DEROGADA** por LO 4/2015, disposicion derogatoria unica, efectos 2015-07-01; se conserva solo porque el banco oficial cita sus cifras: infracciones 3 meses/1/2 anos, multas 30.050,62-601.012,1 EUR). JSON: `derogada: true` | BOE-A-1992-4252 | https://www.boe.es/buscar/act.php?id=BOE-A-1992-4252 | 2015-03-31 | 2025-12-17 | 47 | `29137b1440f7e2ed4aa0391cd7a33b91d5365b472b3c85cbb77c600988bd1431` |
| `reglamento-cartucheria` | RD 989/2015, Reglamento de articulos pirotecnicos y cartucheria (arts. 104, 136, 167; ITC 15) | BOE-A-2015-12054 | https://www.boe.es/buscar/act.php?id=BOE-A-2015-12054 | 2025-04-10 | 2025-12-19 | 253 | `e837617cc36f24fe1a1489b134fae8c8b71064a46b1fd0513ed9e7364245d3b0` |
| `orden-int-2202-2014` | Orden INT/2202/2014, regimen de reproducciones o replicas de armas de fuego antiguas (art. 11 polvora negra) | BOE-A-2014-12249 | https://www.boe.es/buscar/act.php?id=BOE-A-2014-12249 | 2014-11-26 | 2025-12-19 | 16 | `01710a3f43e89ee32a3d4037ec7c161723118ffb95f3f7556b0fe1b546464120` |
| `resolucion-2015-reproducciones` | Resolucion 27-3-2015 DGGC, medidas de seguridad para guardar replicas/reproducciones en domicilios (Primero: clase III UNE EN 1143-1) | BOE-A-2015-3779 | https://www.boe.es/buscar/act.php?id=BOE-A-2015-3779 | 2015-04-09 | 2025-12-19 | 5 | `099343adb2cf1c3d00890bb4dbf8aa1db22ef5754bd05ec36bc8932912db9f60` |
| `resolucion-2024-cajas-fuertes` | Resolucion 4-12-2024 DGGC, cajas fuertes/armeros minimos en domicilios (sustituye a la de 1998) | BOE-A-2025-387 | https://www.boe.es/buscar/act.php?id=BOE-A-2025-387 | 2025-01-08 | 2025-12-20 | 9 | `03dc55af32fdb4d6411173e557ec634339635c79f27770f8d4df61cffc9b7679` |
| `resolucion-2024-transporte` | Resolucion 27-11-2024 DGGC, medidas de seguridad para almacenar armas durante el transporte | BOE-A-2025-386 | https://www.boe.es/buscar/act.php?id=BOE-A-2025-386 | 2025-01-08 | 2025-12-20 | 7 | `93043cc697ed7a3a7ca4aadbf0e79b3d6e96e458d0041585a1caaa8eb1bb2953` |
| `resolucion-1998-cajas-fuertes` | Resolucion 26-11-1998 DGGC, cajas fuertes/armarios (**DEROGADA** por la de 4-12-2024) | BOE-A-1998-28108 | https://www.boe.es/buscar/act.php?id=BOE-A-1998-28108 | 2025-01-08 | 2025-12-18 | 6 | `f1dfc47295a1d33ec4358145741c82cbea9a00695163ef5f9161dd1afb7affba` |
| `reglamento-explosivos` | RD 130/2017, Reglamento de Explosivos (solo contexto: ITC 26 festejos con avancarga, UNE-EN 1143-1 en ITC de seguridad; **no** regula coleccionistas de armas) | BOE-A-2017-2313 | https://www.boe.es/buscar/act.php?id=BOE-A-2017-2313 | 2025-10-10 | 2025-12-19 | 279 | `8d71c77b370f7a852dcb294b074bc9bd65ddd4ee59594a34f6e26b55fd755eea` |
| `reglamento-explosivos-1998` | RD 230/1998, Reglamento de Explosivos (**DEROGADO** por RD 130/2017; art. 297: sanciones prescriben 1/2/4 anos, cifra del banco t5-008..010) | BOE-A-1998-5934 | https://www.boe.es/buscar/act.php?id=BOE-A-1998-5934 | 2017-03-04 | 2025-12-18 | 316 | `eeeb57d8aaa90de1d67d731d34080b1651a965c9a87e19aca91509ef73fda832` |
| `reglamento-cartucheria-2010` | RD 563/2010, Reglamento de articulos pirotecnicos y cartucheria (**DEROGADO** por RD 989/2015, disp. derog. unica, aunque la API aun marca `estatus_derogacion=N`; art. 200.1: sanciones 1/2/4 anos) | BOE-A-2010-7333 | https://www.boe.es/buscar/act.php?id=BOE-A-2010-7333 | 2015-11-07 | 2025-12-19 | 224 | `1c1b2394d2d149eca457a0c84ec60322c60a4df8396bfdb8c965aa96c9827bed` |

Los sha256 completos estan en cada JSON (`sha256_texto_xml`) y se pueden recalcular con `sha256sum fuentes/boe/raw/*.texto.xml`.
Nota: el ID `BOE-A-1998-7655` del encargo no existe en la API; la Orden de 18-3-1998 de pruebas es **BOE-A-1998-7416**
(BOE-A-1998-7417 es otra Orden distinta, sobre el fichero de ADN, no relevante).

Campos JSON: `norma, titulo_oficial, id, url, api, consolidado_hasta` (= "ultima actualizacion publicada" de la pagina BOE),
`ultima_actualizacion_boe` (marca de la API), `retrieved`, `sha256_texto_xml`, `modificadores` (id -> titulo de cada norma
que modifico algun precepto) y `articles[]` con `ref` ("art. 90", "disp. final segunda", "ITC 2, Anexo I", "preambulo"), `title`
(rubrica, vacia en el Reglamento), `text` (literal, UTF-8, sin HTML; las tablas van como filas `a | b`), `url` (enlace profundo
`...act.php?id=ID#<anchor>`; los anchors `aN`/`ar-N` existen en la pagina de BOE), `contexto` (capitulo > seccion), `derogado`,
`notas` ("Tengase en cuenta...", "Se modifica por...", tal como las marca BOE) y `modificaciones` (lista de
{por, publicacion, vigencia} de cada version posterior a la original: p. ej. art. 2 -> BOE-A-2020-9134 = RD 726/2020;
RD 653/2023 = BOE-A-2023-16643). El texto es siempre la ultima version vigente a 2026-10-19.

Verificacion hecha: las 1.176 lineas (>=40 caracteres) del Reglamento, y las de las demas normas, aparecen literalmente (ignorando
espacios/puntuacion) en la pagina HTML oficial de BOE. Reglamento: articulos 1-171 completos y sin huecos (+ 48 bis, 107 bis).

## Avisos importantes (el banco de preguntas puede ir por detras del texto vigente)

1. **Regimen sancionador (tema 5)**: el banco sigue el Reglamento, Cap. VIII (arts. 155-164), que aun cita la LO 1/1992 (derogada) y
   mantiene las cuantias: muy grave 30.050,61-601.012,10 EUR; grave 300,51-30.050,61; leve hasta 300,51 (arts. 155-157). La
   **LO 4/2015 vigente** (arts. 35-40) dice: muy graves 30.001-600.000 EUR, graves 601-30.000, leves 100-600 (art. 39); infracciones
   prescriben a los 6 meses / 1 ano / 2 anos (leve/grave/muy grave, art. 38); sanciones prescriben al ano / 2 anos / 3 anos (art. 40).
   El banco responde 3 meses / 1 ano / 2 anos y 1 / 2 / 4 anos (t5-005..010): coincide con la LO 1/1992, **no** con la LO 4/2015.
   Decidir por pregunta si la explicacion cita el Reglamento (respuesta del banco) y avisa de la diferencia con la LO 4/2015.
2. **"Piezas fundamentales" (t1-041..046)**: el Reglamento vigente usa "componentes esenciales" (art. 1.2): armas cortas = armazon,
   canon, tambor, corredera o cerrojo; armas largas = caja/cajon de mecanismos, canon, cerrojo o bascula, cierre o bloqueo del cierre.
   Las respuestas del banco ("bascula y canon", "cerrojo y canon") son la terminologia antigua.
3. **t7-001** NO es una discrepancia: el enunciado dice "anterior al 1 de enero de **1899**" y la respuesta oficial es B «Falso», que coincide con
   el art. 2.2 y el art. 3 (6.a cat., apdo. 2) vigentes, que dicen **1890**. El 1899 del enunciado es la trampa. (t7-003 y t7-005 dicen 1890.)
4. Preguntas con "9 categorias", licencias, tarjeta europea (validez maxima 5 anos, art. 113), revista cada 5 anos (art. 90): coinciden
   con el texto vigente en lo comprobado; el resto requiere repaso pregunta a pregunta al escribir las explicaciones.
5. La Directiva (UE) 2021/555 (arma de fuego, tarjeta europea) no esta en BOE; esta transpuesta en el Reglamento (RD 726/2020,
   art. 2, 112-113, ITC 4/5) y no se ha descargado (fuera de "solo BOE").
6. STS 4-4-2022 (BOE-A-2022-7138) anulo parcialmente el RD 726/2020; el consolidado de BOE ya refleja su efecto en los articulos afectados.

## Normas anadidas el 2026-10-19 (segunda tanda) y de donde sale cada cifra del banco

- **Coleccion / reproducciones de armas antiguas (tema 7)**: no estan solo en el Reglamento de Armas (art. 107):
  - t7-010 (polvora negra): Orden INT/2202/2014 **art. 11**: «Los titulares de reproducciones o replicas de armas de fuego antiguas unicamente podran comprar y utilizar el tipo de municion empleada en las armas originales es decir, municion con polvora negra, y del calibre de las mismas.»
  - t7-011 (100 cartuchos/ano arma corta) y t7-012 (deposito arma larga 200): RD 989/2015 **art. 136.2** («Los titulares de licencia para arma corta solo podran adquirir 100 cartuchos anuales por arma... no sera superior a 150» en deposito) y **art. 136.1** («En ningun caso se podra tener en deposito un numero superior a 200 cartuchos», arma larga rayada; 1.000/ano). Se aplican a las reproducciones por Reglamento de Armas art. 1.3 (la municion sigue el regimen del arma). Ojo: el art. 136 no distingue "coleccionista"; matizar al explicar.
  - t7-006 (caja fuerte clase III): Resolucion 27-3-2015 DGGC, **apartado Primero** (arma corta: clase III UNE EN 1143-1; arma larga: clase I). La habilita el art. 12 de la Orden INT/2202/2014.
- **Cajas fuertes en general**: Resolucion 4-12-2024 DGGC (vigente; deroga la de 1998). Avancarga y categoria 3.a: remite a Reglamento arts. 101.5.a y 107.e.
- **Prescripcion**: infracciones 3 meses/1/2 anos (t5-005..007) = LO 1/1992 **art. 27**; sanciones 1/2/4 anos (t5-008..010) = RD 230/1998 art. 297 y RD 563/2010 art. 200.1 (ambos derogados; la LO 1/1992 NO regula la prescripcion de sanciones). Vigente: LO 4/2015 arts. 38 y 40 (6 meses/1/2 anos; 1/2/3 anos) y RD 989/2015 art. 200 / RD 130/2017 art. 183 (sanciones: 1/2/3 anos).
- **Multas** (t5-018): LO 1/1992 art. 28.1.a (30.050,62-601.012,1 / 300,52-30.050,61 / hasta 300,51 EUR); Reglamento de Armas arts. 155-157. Las cifras en euros son la conversion oficial de las pesetas originales.

## Normas valoradas y NO descargadas

- Ley 5/2014 de Seguridad Privada (BOE-A-2014-3649) y Reglamento de Seguridad Privada RD 2364/1994: las preguntas de "armas de vigilancia
  y guarderia" (2a.1) se resuelven con Reglamento art. 3; no hacen falta (la Ley 5/2014 si esta disponible en la API si se quiere ampliar).
- Orden de 7-3-2000 (BOE-A-2000-4607, ambito de la Orden 18-3-1998): marginal; no incluida. (Los Reglamentos de Explosivos y de
  cartucheria SI se anadieron: ver arriba.)
- Ley de Enjuiciamiento / Codigo Penal (t5-012 non bis in idem): LO 4/2015 art. 45 cubre la pregunta.

## Mapa por tema (articulos de referencia)

R = Reglamento de Armas (`reglamento-armas`), L = LO 4/2015 (`lo-4-2015`).

| Tema | Contenido del banco | Donde esta en la ley |
|---|---|---|
| 1 Funcionamiento y seguridad | t1-001..004 definiciones (automatica, semiautomatica, repeticion, un solo tiro) | R art. 2 apdos. 5, 6, 15, 16, 21 |
| | t1-041..046 "piezas fundamentales" | R art. 1.2 (componentes esenciales) - ver aviso 2 |
| | t1-056..058, t1-059..068 (guardar, transportar, manejar) | seguridad: R art. 144, 146-149 (obligacion de guardar en lugar seguro, no portar cargadas, llevar descargadas/en fundas), art. 39 (envios); ver `buscar.py "lugar seguro"` |
| | t1-005..040, 047..055 (partes, carga, disparo, mecanismos, limpieza) | **sin base legal**: conocimiento tecnico (Resolucion 19-10-1998 Anexo I solo da el temario: "Tema I: funcionamiento de las armas...") |
| 2 Categorias | clasificacion 1a-9a, longitudes, anima, semiautomaticas/automaticas, prohibidas | R arts. 2 (definiciones), 3 (categorias; aire comprimido 24,2 J en 3a.3 / 4a), 4 y 5 (prohibidas), 6 (guerra); ballestas/arcos art. 3 (7a) |
| 3 Circulacion, revista, transferencia | guias de circulacion, envases/precintos, envios, recepcion | R arts. 31-33, 34-38, 39-42, 43-44 |
| | revista | R art. 90 (cada 5 anos); guias de pertenencia arts. 88-89 |
| | cambio de titularidad | R arts. 92-95 (y 72-76 transferencias comerciales) |
| | cesion temporal | R art. 91 |
| 4 Documentacion, licencias, Tarjeta Europea | tipos de licencia, categoria/numero de armas | R arts. 96-104 (A/B/C/D/E: arts. 99-101; caducidad y visado 103-104), 105-106 tarjetas y armas blancas |
| | autorizaciones temporales / perdida-robo | R arts. 103 (nueva concesion), 145 (perdida/robo) |
| | menores | R art. 109 |
| | Tarjeta Europea de Armas | R arts. 112-113; ITC 5 |
| | requisitos, revocacion, pruebas de capacitacion | R arts. 97-98 (requisitos/aptitudes), 102 (pruebas), 137; Orden 18-3-1998 y Resolucion 19-10-1998 |
| 5 Regimen sancionador (cifras del banco: LO 1/1992 arts. 27-28; RD 230/1998 art. 297 para sanciones 1/2/4 anos) | delitos/infracciones, clases, competencia, prescripcion, sanciones, retirada | R Cap. VIII arts. 155-164 (con aviso 1); L arts. 34-40 (clasificacion, 35 muy graves, 36 graves apdo. 10-12, 37 leves, 38 prescripcion, 39 sanciones, 40 prescripcion sanciones), art. 32 (competencias), 45 (penal/administrativo), 28 (armas); arts. 148-149 (portar armas en reuniones/via publica) |
| 6 Reparacion, prueba y deposito | reparacion y modificacion | R art. 26 |
| | pruebas de armas | R art. 27 (fabricantes y comerciantes), art. 3 (bancos de pruebas), 107-108 |
| | deposito, herederos, subastas, chatarra, Ley de Caza | R arts. 93 (fallecimiento, 6 meses/1 ano), 165-171 (deposito, plazos, destino, venta/destruccion), 167 (Ley de Caza; Ley 1/1970 art. 50-51) |
| 7 Coleccion, definiciones, historia | armas antiguas/reproducciones/replicas/municion/inutilizadas/desmilitarizacion | R art. 2 (apdos. 2, 4, 18, 19, 25, 27, 30-33, 35), art. 3 (6a), 107 (uso, 107.c certificado banco de pruebas), 107 bis, 108 (inutilizacion), ITC 2; coleccionista art. 2.23 |
| | t7-006 caja fuerte clase III (reproducciones cortas) | Resolucion 27-3-2015 DGGC, Primero (`resolucion-2015-reproducciones`); R art. 107.e; Orden INT/2202/2014 art. 12 |
| | t7-010 polvora negra en reproducciones | Orden INT/2202/2014 art. 11 (`orden-int-2202-2014`) |
| | t7-011 / t7-012 100 cartuchos anuales (corta) / 200 en deposito (larga) | RD 989/2015 art. 136.1-2 (`reglamento-cartucheria`); R art. 1.3 |
| | historia de la cartucheria/revolveres (t7-013..015) | **sin base legal** (cultura general) |

Preguntas sin articulo (explicacion solo didactica): casi todo el tema 1 (t1-005..040, 047..055, 059..068 salvo los principios generales
de seguridad del art. 144/147), t7-013, t7-014, t7-015, t7-020 (partly art. 2.16/2.12), y todas las que dependen de la tecnica.
