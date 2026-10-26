# Diseño: dirección «Sereno»

Elegida el 19-oct-2026. Complementa la sección 5 de la especificación (paleta y principios) con las decisiones visuales concretas. **Todo valor de aquí vive en `lib/core/theme/`; las pantallas no llevan literales.**

## Carácter
Tranquila y de fiar, cercana a lo nativo: fondo arena, contenido en **tarjetas elevadas** blancas cálidas, mucho aire, botones en **píldora**. El naranja solo en la acción principal; el verde monte es la marca.

## Tokens

### Color (claro / oscuro)
| Token | Claro | Oscuro | Uso |
|---|---|---|---|
| background | `#EFE9DD` | `#141A17` | fondo de pantalla |
| surfaceRaised | `#FFFDF8` | `#1F2824` | tarjetas |
| divider | `#F1ECE2` | `#2A3530` | separadores dentro de tarjetas |
| outline | `#D3CAB8` | `#3A4640` | filete decorativo (no es límite de control) |
| optionBorder | `#968D79` | `#66756D` | borde de opción en reposo y de la píldora secundaria (3,24:1 / 3,12:1 sobre `surfaceRaised`) |
| outlineStrong | `#7A7160` | `#74847B` | círculo de letra, chevrons, radio sin marcar del selector de tema, barra de desplazamiento (≥ 3:1 sobre `background`, `surface`, `surfaceRaised` y `ringTrack`) |
| primary | `#2F5D50` | `#8CC5B2` | marca, anillos, barras |
| brandTile | `#2A5448` | `#2F5D50` | fondo de la tesela del AppMark (escudo `accent` encima: 3,08:1 / 3,30:1) |
| primaryContainer | `#E5EEEA` | `#23362F` | ficha del artículo, opción seleccionada (simulacro) |
| onPrimaryContainer | `#1F3F36` | `#CFE5DC` | texto sobre primaryContainer |
| ringTrack | `#ECE5D7` | `#2C3833` | pista de anillos y barras |
| accent | `#F27A1A` | `#FF8F3A` | botón principal (texto `onAccent` `#1F1A14`) |
| correct / correctContainer | `#2E9E5B` / `#EAF6EE` | `#4CC37E` / `#1E3A2A` | icono ✓ y fondo |
| correctText | `#1E6B3F` | `#7FD6A0` | «APTO», veredicto correcto |
| incorrect / incorrectContainer | `#D64545` / `#FAE3E3` | `#EF6B6B` / `#3E2222` | icono ✗ y fondo |
| incorrectText | `#A62F2F` | `#F4A3A3` | veredicto incorrecto, insignia de fallos |
| noticeContainer / onNoticeContainer | `#FBEBC8` / `#5C3A00` | `#3A2E14` / `#F2D9A0` | recuadro «Aviso: cambio en la norma» (ámbar, **no** el rojo de «incorrecto»; texto 8,65:1 / 9,62:1) |
| textPrimary / textSecondary | `#1D2420` / `#4F5A54` | `#E8EDE9` / `#A9B5AE` | |

Contraste: todos los textos ≥ 4,5:1 sobre su fondo (también `onNoticeContainer` sobre `noticeContainer`); iconos y bordes de control ≥ 3:1 (por eso el borde de reposo es `optionBorder` y no `outline`, que queda en 1,6:1). El test `theme_contrast_test` lo calcula para los dos temas, también el escudo naranja sobre `brandTile`. `correct`/`incorrect` no se usan como color de texto pequeño (para eso, `correctText`/`incorrectText`).

### Forma, sombra y espacio
- Radios: tarjeta grande **24**, tesela **20**, opción **16**, ficha **14**, botón píldora **altura/2** (56 → 28).
- Sombra de tarjeta (solo claro): `0 2 10 rgba(29,36,32,.07)`; botón redondo pequeño: `0 1 3 rgba(29,36,32,.10)`; botón principal flotante: `0 6 16 rgba(242,122,26,.30)`. En oscuro, **sin sombra**: borde 1 px `divider`.
- Márgenes de pantalla 16; separación entre bloques 14–16; relleno de tarjeta 16–20. Escala de espacio 2/4/8/12/16/20/24/32/40 (`Sp.xxs`…`Sp.x4`); bordes `Sp.border` (1) y `Sp.borderStrong` (2); la fila superior de una pantalla (cerrar + progreso) usa `Sp.headerInsets`. Trazos con nombre: `ScoreRing.homeStroke` 8, `resultStroke` 10, `miniStroke` 4 (fila de tema) y `ButtonSpinner.stroke` 2,4.
- Objetivos táctiles ≥ 44 × 44; botones principales 56 de alto.

### Tipografía
**Public Sans** (OFL), empaquetada en la app (variable, `wght` 400–700). Números tabulares en puntuaciones.

| Estilo | Tamaño / peso | Uso |
|---|---|---|
| display | 48 / 700, tabular, tracking −2 % | «17» del resultado |
| score | 34 / 700, tabular | anillo de inicio |
| title | 26 / 700, interlínea 1,22 | títulos de pantalla |
| stem | 21 / 600, interlínea 1,38 | enunciado |
| option | 17 / 400 (600 si es la correcta) | opciones |
| body | 16 / 400, interlínea 1,5 | explicación |
| label | 17 / 700 | botones, títulos de tesela |
| overline | 13 / 600, MAYÚSCULAS, tracking 6 % | etiquetas de sección («TEMAS», «POR TEMA») |
| chip | 16 / 600 | chips de filtro (Fallos); el color lo pone el `chipTheme` |
| buttonCount | 14 / 600 | «15 preguntas para hoy» tras la etiqueta de «Continuar» |
| caption | 12–14 / 400 | aviso legal, subtítulos |

## Componentes
- **AppMark:** tesela redondeada verde monte (`brandTile`, en claro y en oscuro) con el icono de la app dibujado por `AppMarkPainter` (`lib/core/widgets/app_mark_painter.dart`, única fuente de verdad del icono, la splash y el AppMark): anillo de progreso al 80 % (16/20, el aprobado) en `accent` naranja, pista decorativa, y escudo arena `#EFE9DD` con ✓ verde (34 px en la cabecera, 40 px en Ajustes). Por debajo de ~40 px el trazo del anillo no baja de 2,4 dp. En oscuro no se usa `primary` (menta `#8CC5B2`): el naranja quedaría a 1,7:1. Icono de la app: `#2F5D50` a sangre (el naranja `#F27A1A` da 2,70:1 sobre él; es decorativo en el icono, por eso la tesela de la UI en claro sigue siendo `#2A5448`). Los PNG de `assets/branding/` se regeneran con `flutter test test/branding/render_icons_test.dart --dart-define=GENERATE_ICONS=true` y luego `dart run flutter_launcher_icons` y `dart run flutter_native_splash:create`.
- **ScoreRing:** trazo 8 (inicio, 116 px) o 10 (resultado, 168 px), extremo redondeado, pista `ringTrack`. El de resultado lleva una **marca en 16/20** (288°).
- **Tarjeta de inicio:** anillo + etiqueta en mayúsculas + frase de estado + botón «Continuar» en píldora dentro de la misma tarjeta.
- **Teselas** Simulacro / Fallos: 2 columnas, radio 20; Fallos con insignia (`incorrectContainer` / `incorrectText`).
- **Lista de temas:** una sola tarjeta con filas; cada fila con mini anillo de 40 px (número dentro), título y subtítulo de progreso, chevron. Los siete temas están abiertos para todos.
- **OptionCard:** alto mínimo 56, radio 16, círculo de 26 px a la izquierda: en reposo, borde 2 `optionBorder` en la tarjeta y borde 2 `outlineStrong` en el círculo con la letra; seleccionada (simulacro), relleno `primary` y letra blanca, fondo `primaryContainer`, borde 2 `primary`; correcta, ✓ en círculo `correct`, fondo `correctContainer`, borde 2 `correct`; incorrecta, ✗ en `incorrect`, fondo `incorrectContainer`, borde 2 `incorrect`.
- **Explicación:** **dentro de la tarjeta de la pregunta**, bajo un separador (no hoja modal): veredicto en `correctText`/`incorrectText`, texto, ficha del artículo (`primaryContainer`, radio 14, icono de libro). «Siguiente» es una píldora naranja flotante abajo; el contenido hace scroll por debajo con margen inferior suficiente.
- **Aviso de reforma** (`notice` de la pregunta, solo si existe): recuadro **sobre la explicación**, tras «Respuesta correcta», con fondo `noticeContainer`, radio 16, relleno 16, icono `info_rounded` (24) y título «Aviso: cambio en la norma» (`verdict`) en `onNoticeContainer`, y el texto del aviso (`body`) debajo. Es ámbar a propósito: informa, no marca un error, y nunca cambia la respuesta oficial. Sin aviso no se dibuja nada; la ficha del artículo solo aparece si hay `article`; sin explicación se mantiene «Explicación en preparación». Se ve en la práctica y en la revisión del simulacro (`ExplanationBody`).
- **Resultado:** tarjeta con el anillo y la marca de 16, píldora «APTO»/«NO APTO» con icono; tarjeta «Por tema» con barra fina y «x/y»; tarjeta «Preguntas» con el chip de filtro «Solo falladas» (activo por defecto; sin él, las 20) y una fila por pregunta con ✗ (fallada o en blanco) o ✓ (acertada), el enunciado, «Tu respuesta: B» y chevron; tocar una abre la revisión, donde «Anterior» / «Siguiente» (`SecondaryButton`, fijos abajo; apilados si no caben) recorren la lista que se veía.
- **Retomar e historial del simulacro** (`mock_intro_screen.dart`): si hay un simulacro sin entregar que se puede abrir, la introducción empieza con una tarjeta «Tienes un simulacro sin entregar» («12 de 20 respondidas») y su botón principal «Continuar simulacro»; entonces «Empezar otro» pasa a píldora secundaria, pide confirmación y descarta solo el abierto que se ha enseñado, con sus intentos. Debajo, `Overline` «Tus simulacros» y una tarjeta con una fila por simulacro entregado: círculo ✓/✗, fecha, «16 de 20» (tabular), APTO / NO APTO y chevron; abre el resultado. La tesela Simulacro de Inicio dice «Tienes uno sin entregar» cuando hay un simulacro pendiente. Se pueden iniciar simulacros ilimitados.
- **Botones redondos de 44** (cerrar, ajustes) en `surfaceRaised` con sombra pequeña. El de cerrar va **siempre arriba a la izquierda** (pregunta, simulacro y resultado). La zona táctil es de 48 y el **círculo visible** (44) queda alineado con el margen de página de 16, como las tarjetas: las cabeceras (`Sp.headerInsets`, `AptoAppBar`, el botón de Ajustes de Inicio) ceden `Sp.roundButtonInset` (2) de cada lado.
- **Píldora secundaria** (`SecondaryButton`): `surfaceRaised`, sombra pequeña y borde 1 `optionBorder`. Los botones de texto con icono (`TextActionButton`) y los de la barra del simulacro llevan el icono a `IconSize.button` (20); anterior / siguiente usan `arrow_back_rounded` / `arrow_forward_rounded` para pesar lo mismo que el icono de cuadrícula.
- **Chips de filtro** (Fallos): todo el aspecto vive en `chipTheme` (forma de píldora, sombra de la propia forma en claro / borde `divider` en oscuro, texto `typo.chip`); la pantalla no envuelve el chip en nada. Objetivo táctil ≥ 44 (`materialTapTargetSize: padded`), comprobado en test.
- **ScrollEdgeFade** (`lib/core/widgets/scroll_edge_fade.dart`): borde superior e inferior de una lista que termina contra una cabecera o una barra; en vez de cortar una línea por la mitad, el contenido se difumina (16 dp) hacia `background`. El superior solo aparece al haber hecho scroll; el inferior solo mientras queda contenido. No recibe toques. Se usa en pregunta, simulacro y Fallos.
- **Fallos:** cada fila es un botón (mín. 48 dp, chevron): al tocarla se abre el repaso de lo que se lista empezando por esa pregunta (`/fallos/repasar?tema=n&desde=id`; las anteriores van al final). «Repasar todos» flota abajo (`Sp.floatingMargin`) como «Siguiente»; la lista deja `Sp.floatingClearance` de margen inferior para poder pasar por debajo.
- **Repasar los N fallos** del resultado de un simulacro abre `/simulacro/:id/repasar` («Fallos del simulacro»): solo las preguntas falladas o en blanco de **ese** simulacro, en el orden del examen (no la lista global de Fallos).

- **Teoría** (`lib/features/theory/`): la tesela «Teoría» de Inicio (`ActionCard` a todo el ancho bajo Simulacro/Fallos, solo si hay teoría). Lista: texto de introducción, tarjeta destacada «La prueba práctica» en `primary` con texto `onPrimary`, `Overline` «Resúmenes por tema» y una tarjeta con una fila por tema: número en tesela `primaryContainer` (radio 14), título (el del programa oficial, `l10n.temaTitle`, el mismo que en Inicio, la práctica y el resultado), subtítulo con el tiempo de lectura («N min de lectura») y chevron. Los siete temas, la práctica, la AEM y el glosario están abiertos para todos. Lector: `Overline` «Tema N · Teoría», título (`title`), resumen, secciones como `RaisedCard` plegables (respetan `collapsed`) y «Practicar este tema» flotante. Bloques: párrafo y lista (viñeta `primary`); tabla con cabecera `primaryContainer`, columnas de ≥ 104 dp y scroll horizontal si no caben; «Clave para el examen» (estrella, `primaryContainer`); aviso de norma (`NoticeCallout`, el mismo ámbar que en las preguntas); diagramas dibujados con `CustomPainter` (galería de tiro, sector de tiro) o círculos verdes numerados (secuencia), sobre fondo `background`, con `Semantics` descriptivo y nunca armas ni personas.

- **Marcar como dudosa** (simulacro, `mock_screen.dart`): botón de texto con icono arriba a la derecha de la tarjeta de la pregunta (≥ 48 dp). Sin marcar, `outlined_flag_rounded` y «Marcar como dudosa»; marcada, fondo `noticeContainer`, `onNoticeContainer`, `flag_rounded` y «Marcada como dudosa» (nunca solo color; se lee como interruptor). La hoja «Ir a la pregunta» (`MockNavigator`) pone una insignia ámbar con bandera (`FlagBadge`) en la esquina de cada celda dudosa, un resumen «N dudosas · M sin responder» y una leyenda (respondida, sin responder, dudosa). El diálogo de entrega avisa de las dudosas y de las sin responder. Las marcas se guardan con el simulacro (`mocks.flagged`, ids de pregunta) y viajan en el progreso exportado (`flagged`, opcional; formato versión 1).
- **Buscador** (`/buscar`, `lib/features/search/`): icono de lupa (círculo de 44) a la derecha de la cabecera de Teoría y de Fallos, no en Inicio. Campo en píldora (`AptoSearchField`, el del glosario), sin tildes ni mayúsculas, todas las palabras deben aparecer en enunciado u opciones, mínimo 2 letras. Resultados en una tarjeta con filas (tema y enunciado a 3 líneas, chevron) y el total encima (se listan 50 como máximo). Tocar abre la ficha de Fallos; con una pregunta que nunca se falló su botón dice «Practicar este tema». La búsqueda incluye todo el banco de los siete temas.
- **Pregunta del día** (`lib/features/daily/`): `RaisedCard` de radio 20 (`Rad.tile`) bajo la tarjeta de inicio y encima de Simulacro / Fallos. `Overline` «Pregunta del día» y, a la derecha, la insignia de racha («Racha de 3 días»: píldora `primaryContainer`, icono `local_fire_department_rounded` 18 y texto `verdict` tabular en `onPrimaryContainer`; solo si la racha es ≥ 1; si no caben juntos, la insignia pasa debajo de la etiqueta). Pendiente: el enunciado en `body` (hasta 4 líneas) y la píldora secundaria «Responder →» a todo el ancho. Respondida: icono `check_circle_rounded` en `correct`, «Respondida hoy» (`label`) y «Vuelve mañana para seguir con tu racha.» (`subtitle`); sin botón. Se abre en la pantalla de práctica (`/pregunta-del-dia`, una sola pregunta con su explicación; «Terminar» vuelve a Inicio sin resumen). Sin notificaciones. Cambia a medianoche local; si pasa un día entero sin responder, la insignia desaparece y la racha vuelve a 1 al responder.
- **Cifras y plazos:** `ActionCard` a todo el ancho tras Teoría (icono `pin_rounded`). Subtítulo «N preguntas de plazos, edades e importes», con todas las preguntas del banco disponibles. Si el banco no contiene preguntas de cifras, se muestra el estado vacío informativo. La práctica es la de cualquier tema (título «Cifras y plazos»).

## Iconos
Familia **Material redondeada** (`*_rounded`) en toda la app, también en los estados vacíos; nada de `*_outlined`. Tamaños: `IconSize.inline` 18, `button` 20, `base` 24, `hero` 40. Los iconos de veredicto ✓/✗ usan `correct` / `incorrect` (el texto, `correctText` / `incorrectText`).

## Descartado de las propuestas
- El botón «Guardar para repasar» de la pregunta (no está en el alcance P0).
