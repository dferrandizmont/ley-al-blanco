# Gráficos y capturas para las tiendas y el README

Generador determinista de las capturas de marketing de Ley al Blanco (diseño «Sereno»). Es un test de Flutter con la etiqueta `store`: renderiza las pantallas **reales** de la app (banco real de 423 preguntas, base de datos en memoria, reloj fijo del 15-oct-2026, datos sembrados con `Random` fijo) dentro de un marco redondeado, con el título en Public Sans bold sobre el fondo arena.

Código: `app/test/store/store_screenshots_test.dart` y `app/test/store/readme_graphics_test.dart`.

## Cómo regenerarlas

```bash
cd app
flutter test --tags store --run-skipped test/store
```

- La etiqueta `store` está **omitida por defecto** (`app/dart_test.yaml`), así que `flutter test` a secas no las genera (las muestra como omitidas). `--run-skipped` las ejecuta.
- Genera todas las capturas de tienda, las cinco miniaturas del README, la cabecera y el icono. Las mismas entradas dan los mismos píxeles en el mismo entorno (fuentes reales: Public Sans y los iconos Material, cargados en `test/flutter_test_config.dart`; el rasterizado puede variar entre plataformas).
- Para una sola captura: añade `--plain-name "play/03-probabilidad"`.

## Dónde caen

`app/build/store/<destino>/NN-<slug>.png` (`build/` no se versiona).

| Destino | Tamaño (px) | Tienda |
|---|---|---|
| `play` | 1080 × 1920 | Google Play (móvil, 9:16) |
| `ios69` | 1320 × 2868 | App Store, iPhone 6,9" |
| `ios65` | 1284 × 2778 | App Store, iPhone 6,5" |

Cada destino lleva 5 imágenes; `play` añade `03-probabilidad-oscuro.png` (variante oscura de la 3).

### Recursos versionados del README y de Google Play

El mismo comando escribe en `docs/readme/` (desde la raíz del repositorio):

| Fichero | Tamaño (px) | Formato y uso |
|---|---|---|
| `header.png` | 1024 × 500 | PNG RGB de 24 bits, sin transparencia; cabecera del README y gráfico destacado de Play |
| `icon-512.png` | 512 × 512 | PNG RGBA de 32 bits, con fondo opaco a sangre; icono de Play |
| `01-preguntas-explicadas.png` | 540 × 960 | Práctica con explicación |
| `02-simulacro.png` | 540 × 960 | Resultado del simulacro |
| `03-probabilidad.png` | 540 × 960 | Inicio y progreso |
| `04-fallos.png` | 540 × 960 | Repaso de fallos |
| `05-gratis.png` | 540 × 960 | Teoría |

La cabecera y el icono se dibujan con Flutter y `AppMarkPainter`, la misma fuente del icono de la app. La cabecera usa los colores, estilos de Public Sans y espaciado de `lib/core/theme/`. Los textos de marketing viven en el test generador, igual que los títulos de las capturas; no modifican la UI ni sus traducciones.

Las cinco miniaturas son las composiciones claras de Play reducidas a la mitad con el codec de Flutter. `readme_render_support.dart` guarda los PNG sin metadatos y con compresión zlib de nivel 9, usando solo Dart y Flutter, sin nuevas dependencias. Comprueba que los recursos RGB sean opacos; los tests verifican las dimensiones y los formatos RGB/RGBA de cabecera e icono.

Para regenerar solo cabecera e icono:

```bash
cd app
flutter test --tags store --run-skipped test/store/readme_graphics_test.dart
```

Para regenerar solo las cinco miniaturas y sus originales de Play:

```bash
cd app
flutter test --tags store --run-skipped test/store/store_screenshots_test.dart --name "play/"
```

Este último comando también genera la variante oscura de Play en `build/store/play/`, pero no la copia al README. Todos los generadores usan la etiqueta `store`, omitida por `dart_test.yaml` en `flutter test` normal. Versiona los siete PNG de `docs/readme/`, nunca `app/build/`. El exportador público incluye estos recursos desde `HEAD`: confirma primero los cambios, ejecuta `bash tool/publish/export_public.sh <carpeta-temporal-fuera-del-repo>` y comprueba que la copia contiene las siete imágenes.

| Fichero | Título | Pantalla |
|---|---|---|
| `01-preguntas-explicadas` | Las 423 preguntas, explicadas · «Con su artículo del BOE» | Práctica, pregunta t2-010 acertada, con explicación y ficha del artículo |
| `02-simulacro` | Simulacro real: 20 preguntas, apto con 16 | Resultado APTO (18 de 20) |
| `03-probabilidad` | Tu probabilidad de aprobar | Inicio con progreso de un alumno a medias (anillo ≈ 71 %) |
| `04-fallos` | Repasa tus fallos | Lista de Fallos (8 fallos de los 7 temas) |
| `05-gratis` | Gratis. Sin anuncios. | Lista de Teoría con todos los temas abiertos |

Requisitos de las tiendas (verifica en cada consola antes de subir, cambian): Google Play pide 2–8 capturas de móvil, lado corto ≥ 320 px y lado largo ≤ 3,6 × el corto (9:16 vale); App Store pide 1–10 capturas por tamaño de pantalla y acepta 1320 × 2868 (6,9") y 1284 × 2778 (6,5"); PNG o JPEG sin transparencia. Son PNG opacos.

## Reglas (no se negocian)

- **Sin armas.** Ninguna captura muestra una imagen o dibujo de un arma, y menos apuntando a una persona (spec §5 y §8; norma de capturas de Apple). Las pantallas solo contienen texto de preguntas. Si una pregunta nombra un arma, es texto; no se añaden fotos.
- **Sin «oficial».** Ni en los títulos ni en la pantalla («Guardia Civil» tampoco como marca, logos o escudo). La app es independiente y no oficial.
- **Sin logos de Apple ni de Google**, ni marco de dispositivo real, ni barra de estado falsa.
- **Los títulos están en `_shots` del test.** Si se cambia un título, se actualiza también la tabla anterior y se regenera; los saltos de línea del test solo marcan dónde corta la línea en la imagen.
- Colores y tipografía salen de los tokens de `lib/core/theme/` (`AptoColors`, `AptoTypography`), nunca literales.
- Tras regenerar, abre cada PNG y comprueba: tamaño exacto, título legible y sin recortar, contenido real, sin franjas de overflow ni textos de prueba.
