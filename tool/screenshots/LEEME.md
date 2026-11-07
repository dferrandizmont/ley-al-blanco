# Capturas de App Store en un simulador iOS real

`auto_ios.py` hace las capturas de la ficha de App Store con la app **real** corriendo en un simulador de iPhone 17 Pro Max (iOS 26.5): barra de estado a las 09:41, el iPhone con Dynamic Island alrededor y el título encima sobre el fondo arena. Solo español. Adaptado de Ink Lab; no toca el punto de entrada ni los assets de producción.

Las capturas de Google Play **no** salen de aquí: siguen siendo las de `app/test/store/store_screenshots_test.dart` (ver `tool/store/LEEME.md`).

## Requisitos

Mac con Xcode y el runtime iOS 26.5, Flutter (3.47.7), `~/.agents/scripts/heavy.sh` y Python 3 con **Pillow disponible también con `-I`** (por ejemplo, un entorno virtual fuera del repo):

```sh
python3 -m venv ~/.venvs/lab-shots && ~/.venvs/lab-shots/bin/pip install pillow
```

## Regenerar

Desde la raíz del repo:

```sh
~/.venvs/lab-shots/bin/python -I tool/screenshots/auto_ios.py
```

Sin interacción. El script:

1. Crea su **propio** simulador `LAB-Shots` (iPhone 17 Pro Max, `com.apple.CoreSimulator.SimRuntime.iOS-26-5`), lo arranca y fija la barra de estado (9:41, batería llena, cobertura y wifi).
2. Levanta un puente HTTP local (127.0.0.1, con token) y ejecuta `sh ~/.agents/scripts/heavy.sh flutter test integration_test/store_ios_test.dart -d <udid>` (compilación debug del test; no genera una versión de release).
3. El test (`app/integration_test/store_ios_test.dart`) arranca la app real con base de datos nueva, el banco real, el reloj fijo del 15-oct-2026 18:30 y las mismas semillas y datos de demostración que el test de Flutter, navega a cada pantalla y pide la captura al puente. El script hace `simctl io screenshot`, la enmarca y responde; el test no avanza hasta entonces.
4. Escribe los PNG opacos (RGB de 8 bits, **sin alfa**) y comprueba tamaño y modo.
5. Al terminar, **aunque falle**: borra la barra de estado, apaga y **borra el simulador que creó** (`xcrun simctl delete <udid>`). Nunca toca otros simuladores ni dispositivos físicos.

Opciones: `--udid <udid>` usa un simulador ya existente (no se borra); `--timeout` (segundos, incluye la cola de `heavy.sh`); `--reframe` vuelve a enmarcar las capturas crudas guardadas sin simulador (útil para cambiar títulos o colores); `--validate` solo comprueba los PNG.

## Salida

En `app/build/store/` (`build/` no se versiona):

| Carpeta | Tamaño | Juego de la consola |
|---|---|---|
| `ios69/` | 1320 × 2868 | iPhone 6,9" |
| `ios65/` | 1284 × 2778 | iPhone 6,5" |
| `ios63/` | 1206 × 2622 | iPhone 6,3" |
| `ios-raw/` | 1320 × 2868 | Capturas del simulador sin marco (con alfa en las esquinas; no se suben) |

Cinco imágenes por carpeta, en este orden: `01-preguntas-explicadas`, `02-simulacro`, `03-probabilidad`, `04-fallos`, `05-gratis`. Comprobación: `sips -g pixelWidth -g pixelHeight -g hasAlpha app/build/store/ios69/*.png` (`hasAlpha: no`).

**Ojo:** `flutter test --tags store --run-skipped test/store` también escribe `ios63`, `ios65` e `ios69` (con el marco genérico de Flutter) y los sobrescribe. Para App Store, ejecutar este script **después**, o no usar esas carpetas de ese test.

## Qué se ve y dónde se cambia

| Archivo | Pantalla |
|---|---|
| `01-preguntas-explicadas` | Práctica del tema 2 en t2-010, acertada, con explicación y artículo |
| `02-simulacro` | Resultado de un simulacro con 18 aciertos y 2 fallos (apto) |
| `03-probabilidad` | Inicio con progreso de demostración y probabilidad de aprobar |
| `04-fallos` | Repaso de ocho fallos de los siete temas |
| `05-gratis` | Teoría |

- Títulos y subtítulo: tabla `SHOTS` de `auto_ios.py` (los mismos de `store_screenshots_test.dart`; sin «oficial» ni imágenes de armas).
- Colores: arena de fondo, texto principal y secundario del tema claro (tokens de `lib/core/theme/apto_colors.dart`), Public Sans bold. `WASH = True` añade el velo verde suave bajo el título que llevan las capturas de Play.
- Datos y navegación de cada pantalla: `app/integration_test/store_ios_test.dart` (se omite solo si no hay puente, así que la batería QA no se ve afectada).

Comprobar siempre a ojo cada PNG: textos cortados, teclado, diálogos, barra a las 09:41.
