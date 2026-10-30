[English](CONTRIBUTING.md) · **Español**

# Contribuir

Son bienvenidos los informes de errores, las ideas y las traducciones. En la app,
el botón «¿Ves un error? Avísanos», bajo cada explicación, abre tu aplicación de
correo con el contenido de la pregunta, y el soporte es leyalblanco@mainshai.com.

## Compilar y probar

Requisitos: Flutter **3.47.7**, Android SDK para Android o macOS con Xcode para
iOS. La app usa Riverpod, go_router y Drift para el estado, la navegación y la
base de datos local.

Desde la raíz:

```bash
cd app
flutter pub get
flutter analyze
flutter test
flutter run
```

APK de pruebas locales, sin `app/android/key.properties`:

```bash
flutter build apk --release -PallowDebugSigning=true
```

Usa la clave de depuración de la máquina. Los APK públicos requieren una clave
del dueño fuera del repositorio: [firma de release](docs/release-signing.md).
Los ficheros generados se versionan; si cambias sus fuentes:

```bash
dart run build_runner build -d
flutter gen-l10n
```

Para regenerar el contenido hacen falta Python **3.11 o superior** y `pdftotext`
(Poppler o Xpdf). Sigue el [pipeline de contenido](tool/content/README.md);
no edites los JSON generados a mano. El banco se comprueba con SHA-256 al importarlo.

[Pruebas en dispositivo](docs/qa.md) ·
[Regenerar gráficos y capturas](tool/store/LEEME.md) ·
[Especificación](licencia-armas-spec.md) · [Diseño](docs/design-sereno.md).
