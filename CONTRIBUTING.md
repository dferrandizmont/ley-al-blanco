**English** · [Español](CONTRIBUTING.es.md)

# Contributing

Bug reports, ideas and translations are welcome. In the app, the «¿Ves un error?
Avísanos» button under every explanation opens your email app with the question
details, and support is dev@mainshai.com.

## Build and test

Requirements: Flutter **3.47.7**, Android SDK for Android or macOS with Xcode for
iOS. The app uses Riverpod, go_router and Drift for state, navigation and the
local database.

From the repository root:

```bash
cd app
flutter pub get
flutter analyze
flutter test
flutter run
```

Local test APK, without `app/android/key.properties`:

```bash
flutter build apk --release -PallowDebugSigning=true
```

It uses the machine's debug key. Public APKs require the owner's key outside the
repository: [release signing](docs/release-signing.md). Generated files are
versioned; if you change their sources:

```bash
dart run build_runner build -d
flutter gen-l10n
```

Regenerating the content needs Python **3.11 or later** and `pdftotext` (Poppler
or Xpdf). Follow the [content pipeline](tool/content/README.md); do not edit the
generated JSON by hand. The question bank is checked with SHA-256 when it is
imported.

[Device tests](docs/qa.md) ·
[Regenerate graphics and screenshots](tool/store/LEEME.md) ·
[Specification](licencia-armas-spec.md) · [Design](docs/design-sereno.md).
