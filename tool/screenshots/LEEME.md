# Capturas de App Store en un simulador iOS real

`auto_ios.py` hace las capturas **crudas** de la ficha de App Store con la app **real** corriendo en un simulador de iPhone 17 Pro Max (iPhone 6,9", iOS 26.5): la pantalla tal cual, con la barra de estado a las 09:41 y sin marco ni título. Solo español. Adaptado de Ink Lab; no toca el punto de entrada ni los assets de producción.

El marco de iPhone, el titular y el tamaño final (1290 × 2796) los pone el generador compartido `store_shots.py` (skill `readme-app`, §4), el mismo que hace las de Google Play, a partir de `docs/store/shots.json`.

## Requisitos

Mac con Xcode y el runtime iOS 26.5, Flutter (3.47.7), `~/.agents/scripts/heavy.sh` y Python 3 con **Pillow disponible también con `-I`** (por ejemplo, un entorno virtual fuera del repo):

```sh
python3 -m venv ~/.venvs/lab-shots && ~/.venvs/lab-shots/bin/pip install pillow
```

## Regenerar

Desde la raíz del repo, en dos pasos:

```sh
# 1. Capturas crudas del simulador -> docs/store/ios/es/
~/.venvs/lab-shots/bin/python -I tool/screenshots/auto_ios.py
# 2. Marco y titular -> docs/store/es/appstore/ (1290 x 2796)
~/.venvs/lab-shots/bin/python -I ~/.agents/skills/readme-app/scripts/store_shots.py docs/store/shots.json
```

El paso 2 también regenera las de Google Play (`docs/store/<idioma>/play/` y `fastlane/metadata/android`) desde `docs/readme/`; si no se ha tocado `docs/readme/`, el resultado es el mismo y no hay que confirmar nada de eso (`git status` lo dice). Lo que falta (el inglés no tiene capturas de iOS) se salta con aviso.

El paso 1 no tiene interacción. El script:

1. Crea su **propio** simulador `LAB-Shots` (iPhone 17 Pro Max, `com.apple.CoreSimulator.SimRuntime.iOS-26-5`), lo arranca y fija la barra de estado (9:41, batería llena, cobertura y wifi).
2. Levanta un puente HTTP local (127.0.0.1, con token) y ejecuta `sh ~/.agents/scripts/heavy.sh flutter test integration_test/store_ios_test.dart -d <udid>` (compilación debug del test; no genera una versión de release).
3. El test (`app/integration_test/store_ios_test.dart`) arranca la app real con base de datos nueva, el banco real, el reloj fijo del 15-oct-2026 18:30 y los datos de demostración de `app/integration_test/support/store_demo.dart`, navega a cada pantalla y pide la captura al puente. El script hace `simctl io screenshot`, la guarda y responde; el test no avanza hasta entonces.
4. Escribe los PNG (RGB de 8 bits, **sin alfa**, 1320 × 2868) y comprueba tamaño y modo.
5. Al terminar, **aunque falle**: borra la barra de estado, apaga y **borra el simulador que creó** (`xcrun simctl delete <udid>`). Nunca toca otros simuladores ni dispositivos físicos.

Opciones: `--udid <udid>` usa un simulador ya existente (no se borra); `--timeout` (segundos, incluye la cola de `heavy.sh`); `--validate` solo comprueba los PNG.

## Salida

| Qué | Dónde | Tamaño |
|---|---|---|
| Capturas crudas (se versionan) | `docs/store/ios/es/<nombre>.png` | 1320 × 2868 |
| Capturas de la ficha (las que se suben) | `docs/store/es/appstore/<nombre>.png` | 1290 × 2796 |

Cinco imágenes, en este orden: `01-probabilidad`, `02-simulacro`, `03-fallos`, `04-tarjetas-cifras`, `05-glosario`. Comprobación: `sips -g pixelWidth -g pixelHeight -g hasAlpha docs/store/es/appstore/*.png`.

`flutter test --tags store --run-skipped test/store` (ver `tool/store/LEEME.md`) escribe además `app/build/store/ios*` con un marco genérico de Flutter: **no se usan** para App Store.

## Qué se ve y dónde se cambia

Son las cinco pantallas de `docs/readme/es/`:

| Archivo | Pantalla |
|---|---|
| `01-probabilidad` | Inicio con el progreso de demostración y la probabilidad de aprobar |
| `02-simulacro` | Resultado de un simulacro con 17 aciertos y 3 fallos (apto), en 20 min 31 s |
| `03-fallos` | Lista de los 20 fallos pendientes |
| `04-tarjetas-cifras` | Tarjeta de cifras t4-032 con la respuesta revelada |
| `05-glosario` | Teoría, glosario |

- Titulares: `docs/store/shots.json` (los mismos que Google Play; sin «oficial» ni imágenes de armas).
- Datos de demostración (cobertura, fallos, tiempo del simulacro, semilla de la tarjeta): `app/integration_test/support/store_demo.dart`. El orden de las tarjetas de cifras es aleatorio: `kDemoFiguresSeed` es la semilla con la que la primera es t4-032; si cambia el banco, hay que buscar otra.
- Navegación de cada pantalla: `app/integration_test/store_ios_test.dart` (se omite solo si no hay puente, así que la batería QA no se ve afectada).

Comprobar siempre a ojo cada PNG: textos cortados, teclado, diálogos, barra a las 09:41.
