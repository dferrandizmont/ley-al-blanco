# QA antes de cada release

Dos cosas distintas: una **batería automática** (`tool/qa/run_battery.sh`) que conduce la app real en el emulador `Apto_Armas`, y una **pasada manual corta** (al final) para lo que una máquina no puede juzgar. Las pruebas y los requisitos de publicación de iOS se comprueban además en un dispositivo y en App Store Connect.

Decisión del 26-oct-2026: un único APK con todo abierto; sin tienda simulada ni defines de compras. La cantidad de escenarios ha cambiado al retirar los de compra. `flutter analyze` comprueba su compilación; ejecutar la batería nativa antes de publicar.

## Una orden

```bash
tool/qa/run_battery.sh        # Git Bash en Windows o macOS, desde la raíz del repo
```

Hace, por orden:

1. Arranca el AVD `Apto_Armas` si no está en marcha (espera a `sys.boot_completed`). **Solo toca ese emulador**: los de otros proyectos nunca se arrancan, paran ni direccionan (todo va con `adb -s <serial>`).
2. `flutter test` (unidad y widgets).
3. `flutter test integration_test -d <serial>` (escenarios de extremo a extremo).
4. `tool/qa/release_smoke.sh` (build de release con R8 + abrirlo).
5. Imprime una tabla (pasa / falla por etapa y por escenario) y la guarda en `app/build/qa/last-run.md`. `app/build/` ya está en el `.gitignore`: nada de esto entra en git.
6. Al final para, por PID, solo los daemons de Gradle nuevos cuyo log muestra que compilaron este proyecto y ningún otro (los que ya existían al empezar o compartió otra sesión no se tocan; `QA_NO_GRADLE_STOP=1` lo evita). Nunca `gradlew --stop`: pararía los de todas las sesiones de la máquina. El emulador se deja encendido.

Código de salida: `0` todo en verde, `1` algo falla, `2` falla el entorno (sin adb, el emulador no arranca, no compila).

Variables útiles:

| Variable | Efecto |
|---|---|
| `QA_STAGES=integration` | Solo esas etapas (`unit,integration,smoke`). |
| `QA_ONLY=arranque,ajustes` | Solo esos escenarios (un nombre también elige su familia: `ajustes` → `ajustes_tema`...). |
| `QA_SKIP=ajustes` | Deja fuera esos escenarios. |
| `QA_SERIAL=emulator-5554` | Usa ese serial en vez de buscar `Apto_Armas`. |
| `QA_NO_GRADLE_STOP=1` | No para los daemons de Gradle que arrancaron nuestras builds. |

A mano, sin los scripts: `cd app && flutter test integration_test -d <serial> [--dart-define=QA_ONLY=arranque]`.

### Cuánto tarda

| Etapa | Tiempo aproximado |
|---|---|
| Unidad y widgets | ~1 min |
| Integración (escenarios vigentes) | unos 11 min con la app ya compilada; la primera vez suma 3-4 min de build de Gradle |
| Smoke de release | 30 s con el APK hecho; 3-5 min si hay que compilarlo |
| **Total** | **~20 min** la primera vez, ~15 min después |

## Qué cubre la batería de integración

Cada escenario arranca la **app real** (`LeyAlBlancoApp`, router, pantallas) sobre una **base Drift nueva** en el dispositivo, con las preferencias vacías y el banco real de 423 preguntas importado por el bootstrap. Lo único sustituido: la semilla del `Random` y el reloj (hoy a las 10:00, avanzando en tiempo real). Las respuestas correctas/incorrectas salen del `questions.json` del banco, no de adivinar.

| Escenario | Qué demuestra |
|---|---|
| `arranque` | El bootstrap importa 423 preguntas (68/67/66/70/66/64/22); Inicio muestra el anillo, «Continuar · 15 preguntas para hoy», 7 temas abiertos, las teselas de «Cifras y plazos» y «Tarjetas de cifras» (abiertas), Simulacro, Fallos, botón de Ajustes, aviso legal y edición. |
| `practica_tema1` | 3 respuestas (1 fallo, 2 aciertos): estados ✓/✗ de las tarjetas, «Correcto/Incorrecto», área de explicación y «Siguiente»; intentos guardados; al volver, Fallos «1 fallo pendiente» y tema 1 «1 fallo». |
| `repaso_del_dia` | «Continuar» (modo srs): la pregunta fallada vuelve la primera, la cola es 1 vencida + 12 nuevas (cuota 15 − 3), las nuevas son del tema con menos dominio (el 2: el 1 ya tiene aciertos), la cola baja a 12 al repasarla. |
| `persistencia_tras_reinicio` | Cerrar y abrir la app conserva fallos y cola; el banco no se importa dos veces. |
| `fallos_y_revision` | Lista de Fallos, filtro por tema, «Repasar todos» (también filtrado) y dos aciertos seguidos sacan la pregunta de la lista . |
| `cifras_y_plazos` | «Cifras y plazos» con todo el contenido abierto: solo preguntas con cifra, un fallo guardado en modo práctica (y en Inicio) y el enunciado de la pregunta en pantalla. |
| `cifras_tarjetas_completa` | Tarjetas de cifras (`/cifras/tarjetas`) con todo el contenido abierto: la tesela de Inicio con el número de tarjetas y sin candado; «Ver respuesta» (respuesta oficial, explicación y artículo), «La sabía», «Repasar otra vez» (la tarjeta vuelve al final del mazo y el progreso no avanza), el resumen («Sabías 75 de 76 a la primera») y «Otra vez con las que repasé» (solo la repetida, de nuevo); la ronda no guarda intentos ni progreso. |
| `pregunta_del_dia` | Pregunta del día en Inicio: se responde, aparece «Respondida hoy» y «Racha de 1 día», y siguen ahí tras cerrar y abrir la app. |
| `practica_avisanos` | Tras responder aparece «¿Ves un error? Avísanos» (con bandera) y abre un correo con la pregunta. |
| `simulacro_aprobado` | Simulacro: 16 aciertos + 4 fallos (10 respondidas en orden y 10 saltando por el navegador); diálogo «Entregar»; **APTO**, 16 «de 20», reparto 3/3/3/4/3/3/1 con los aciertos por tema; «Repasar los 4 fallos» abre una revisión de exactamente esos 4. |
| `simulacro_suspenso` | 15 aciertos: **NO APTO**, marca de 16, «Repasar los 5 fallos». |
| `simulacro_en_blanco` | Entregar con 19 en blanco: el diálogo avisa de 19 sin responder, NO APTO, las 19 aparecen como «Sin responder» y se pueden abrir. |
| `simulacro_tiempo` | El resultado del simulacro dice «Tiempo empleado: X min Y s»: el tiempo guardado entre el inicio y la entrega. |
| `salir_del_simulacro` | Cerrar y «atrás» del sistema piden confirmación; «Seguir» se queda; abandonar deja el simulacro abierto para retomarlo, sin intentos guardados. |
| `ajustes` | Licencias de código abierto, filas del banco (edición «Cuestionario GC nov-2020», 423, «Consultado»), texto legal. |
| `ajustes_tema` | Sistema/Claro/Oscuro cambian la app (y Sistema sigue al móvil); la elección persiste al reiniciar. |
| `datos` | Ajustes > «Tus datos»: aparecen «Exportar progreso» e «Importar progreso»; exportar ofrece al usuario `ley-al-blanco-progreso-AAAA-MM-DD.json` con `format`/`version` correctos. |
| `datos_invalido` | Importar un archivo no válido (o demasiado grande) muestra el error y no escribe nada (0 respuestas). |
| `datos_importar` | Importar un archivo válido pide confirmación (cancelar no cambia nada), reemplaza el progreso y Inicio lo muestra al momento («1 fallo pendiente»). |
| `teoria` | Inicio abre Teoría, entra en el resumen del tema 1  y vuelve. Se omite con una nota `QA_NOTE` si el build no incluye `teoria.json`. |
| `simulacro_dudosas` | Simulacro: «Marcar como dudosa» (icono de bandera y texto «Marcada como dudosa»), el mapa «Preguntas» las destaca con su resumen y leyenda, el diálogo de entrega avisa («Tienes 2 dudosas y 19 sin responder…») y, tras cerrar y reabrir la app, «Continuar simulacro» las devuelve. |
| `busqueda_completa` | Buscar desde Teoría con todo el banco; atrás vuelve a Teoría. |
| `modo_oscuro` | Recorrido (Inicio, práctica con feedback, Fallos, simulacro con navegador y diálogo, Ajustes) en oscuro sin excepciones de framework. |
| `texto_grande` | El mismo recorrido con el texto al 130 %: sin desbordes (`takeException()` vacío en cada paso). |
| `pantalla_pequena` | El mismo recorrido en 320×568 (iPhone SE), 130 % y oscuro. |

Limitaciones conocidas: integración no pasa por R8 (lo hace el smoke) ni juzga el acabado visual. Las compras ya no forman parte de la app.

## Smoke de release

`tool/qa/release_smoke.sh [apk]`: compila (si no se le pasa APK) el APK de prueba como en `docs/release-signing.md` §8 (arm64, `-PallowDebugSigning=true`, ofuscado; si el emulador no admite arm64, x64). Usa la clave de depuración de la máquina, nunca una clave incluida en el repo. Desinstala la app, instala el APK, lo abre, espera ~8 s, y comprueba:

- la **primera pantalla** pintada: `uiautomator dump` contiene «Ley al Blanco» y «Simulacro»;
- el log `adb logcat -d -s flutter:E AndroidRuntime:E` **sin** `NoSuchMethodError|ClassNotFoundException|FATAL EXCEPTION|Unhandled Exception` (el síntoma de R8 quitando código que se llama por JNI);
- que el proceso sigue vivo.

Evidencias en `app/build/qa/smoke/`: `first-screen.png`, `ui-dump.xml`, `logcat-errors.txt`, `logcat-full.txt`, `summary.txt`. Código de salida `0` bien, `1` la app está rota, `2` falla el entorno. Cuando compila, termina parando su propio daemon de Gradle por PID.

## Cómo leer un fallo

1. `app/build/qa/last-run.md`: qué etapa y qué escenario.
2. `app/build/qa/integration-summary.md`: el mensaje del escenario (`expect` que falló) y, tras `SCREEN:`, los textos que había en pantalla en ese momento. Suele bastar para ver si es un texto cambiado o un flujo roto.
3. `app/build/qa/shots/<escenario>.png`: captura del emulador en el instante del fallo.
4. `app/build/qa/integration.log`: el log completo. Cada escenario escribe `QA_START|id|…` y `QA_RESULT|id|PASS|ms|` o `FAIL`; `QA_TRACE` lleva el stack.
5. Para repetir uno solo: `QA_STAGES=integration QA_ONLY=ajustes tool/qa/run_battery.sh`.

Causas habituales:

- **Cambió un texto de la UI**: los textos esperados están todos en `app/integration_test/support/qa_texts.dart`. Es un cambio consciente: se actualiza ahí.
- **Cambió una pantalla** (otro orden, otro widget): los helpers de `support/qa_ui.dart` buscan por texto, tipo de widget (`OptionCard`, `TemaCard`, `MockNavigator`) y tooltip («Cerrar», «Ajustes», «Atrás»).
- **«Framework exception … overflowed»** en `modo_oscuro`/`texto_grande`/`pantalla_pequena`: es un fallo real de maquetación, no del test.
- **Fallo de Gradle** («Gradle build daemon has been stopped», «Could not find implementation class»): otro proceso hizo `gradlew --stop` o escribía la caché a la vez. El script reintenta una vez; si persiste, repetir.
- **El emulador no responde**: `adb devices` con `offline`. El script solo mata un `offline` si `adb -s <serial> emu avd name` dice `Apto_Armas`; si no, hay que arrancarlo a mano: `"$LOCALAPPDATA/Android/Sdk/emulator/emulator.exe" -avd Apto_Armas -no-boot-anim -netdelay none -netspeed full`.
- La batería **desinstala** la app del emulador al instalar el build de debug/release (la firma es la misma, el `versionCode` cambia): no guardar nada importante en él.

Añadir un escenario: una función `qaScenario('id', 'título', (tester) async { final app = await launchApp(tester, …); … })` en `app/integration_test/scenarios/`, registrada en `qa_test.dart`. Helpers: `launchApp` (arranque real, `dark`, `textScale`, `logicalSize`), `app.restart()`, `answerPractice`, `playMock`, `submitMock`, `currentQuestion` (identifica la pregunta en pantalla contra el banco).

## Pasada manual por release (lo que no se automatiza)

Una persona (o un agente con capturas) la hace en el emulador o en un móvil, con el APK de release de prueba, **después** de la batería en verde. 15-20 minutos.

**Aspecto y lectura**
- [ ] Inicio, práctica, simulacro, resultado, Fallos, teoría y Ajustes **se ven bien**: nada cortado, alineado o apretado; jerarquía clara.
- [ ] Los textos tienen sentido y están bien escritos (sin faltas, sin frases técnicas, sin «oficial» ni logos ni escudo).
- [ ] El enunciado se lee cómodo (18-20 pt) y las tres opciones son tarjetas a todo el ancho. Correcto/incorrecto se distingue **sin** el color (✓/✗).
- [ ] La explicación y el artículo citado tienen sentido para la pregunta mostrada (muestrear 3-4 preguntas de temas distintos).

**Modos y tamaños**
- [ ] Modo oscuro: contraste correcto en todas las pantallas, sin blancos que deslumbren.
- [ ] Texto grande del sistema (130-200 %): nada se corta y todo es alcanzable con scroll.
- [ ] Pantalla pequeña (iPhone SE o AVD de 320×568): el botón «Continuar», las opciones y «Siguiente» se ven y se tocan.
- [ ] Giro de pantalla / ventana dividida: no se rompe.

**Release real (R8)**
- [ ] Instalar el APK ofuscado de `release_smoke.sh` en un móvil físico (no solo el emulador) y abrirlo **sin conexión**: llega a Inicio.
- [ ] Contestar unas preguntas, cerrar la app desde recientes, abrirla: el progreso sigue.
- [ ] Un simulacro entero a mano, hasta el resultado y «Repasar los fallos».
- [ ] Ajustes > Tus datos, a mano (los escenarios `datos*` sustituyen los diálogos del sistema, que no se pueden automatizar): «Exportar progreso» abre el diálogo del sistema (Android: elegir carpeta y nombre; iPhone: hoja de Archivos), el archivo queda donde se eligió y **no se pidió ningún permiso de almacenamiento**; en otro móvil (o tras borrar los datos), «Importar progreso» lo abre desde el selector del sistema, pide confirmación y deja el progreso igual; un `.json` cualquiera da «No se puede importar».
- [ ] Ajustes: aviso legal («app independiente y no oficial») y edición del banco visibles; licencias de código abierto, política de privacidad y contacto abren.

**Antes de subir**
- [ ] `python tool/content/check_sources.py` sale con 0: los PDF de la Guardia Civil no han cambiado desde la descarga guardada (sha256 y `Last-Modified`). Si sale 1, mirar qué cambió antes de publicar (`tool/content/README.md`). Sin red: `--offline` solo verifica los ficheros locales.
- [ ] `flutter analyze` limpio y `flutter test` verde (la batería ya lo hace).
- [ ] `version:` de `pubspec.yaml` subida (`docs/release-signing.md` §6) y los símbolos de ofuscación guardados.
