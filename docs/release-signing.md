# Firma de release (Android)

Ley al Blanco: `applicationId` `es.leyalblanco.app` (nombre decidido el 23-oct-2026; hasta 0.7.1 fue `app.aptoarmas.apto_armas` como «Apto Armas»). Sin servidor: la configuración de release solo depende de la firma y los enlaces opcionales `SUPPORT_EMAIL` y `PRIVACY_URL`.

Comprobaciones de release que **ya están implementadas**:

- `app/android/app/build.gradle.kts` se niega a compilar un release si falta `app/android/key.properties`, salvo que se pase `-PallowDebugSigning=true` (firma con la **clave de depuración de la máquina**, ver §8; **solo pruebas locales**, nunca distribución pública).
No se guarda ninguna clave ni contraseña en el repositorio: `key.properties`, `*.keystore` y `*.jks` van en `.gitignore`, sin excepciones.

## 1. Crear la upload keystore (una vez, fuera del repo)

```bash
keytool -genkeypair -v -keystore ~/ley-al-blanco-upload.jks -alias upload -keyalg RSA -keysize 4096 -validity 10000
```

- [ ] Guardar el `.jks` y las contraseñas en un gestor de contraseñas, con copia de seguridad.
- [ ] Nunca commitearlo ni enviarlo por correo. Perder la upload key se recupera con Play (solicitud de reseteo); filtrarla no.

## 2. Apuntar el build a la keystore

Crear `app/android/key.properties` (ignorado por git):

```properties
storeFile=/ruta/absoluta/ley-al-blanco-upload.jks
storePassword=<del gestor de contraseñas>
keyAlias=upload
keyPassword=<del gestor de contraseñas>
```

`storeFile` se resuelve relativo a `app/android/` si no es absoluto. En CI, escribir el fichero desde secrets al compilar y borrarlo después. `signingConfigs.release` solo se crea si están las cuatro propiedades.

## 3. Play App Signing

- [ ] Dar de alta la app en Play Console con Play App Signing (Google guarda la clave de firma; la de arriba es solo de subida).
- [ ] Subir un AAB (`flutter build appbundle`), no un APK.

## 4. Build de release

Desde `app/` (`<version>` = `version:` de `pubspec.yaml`, p. ej. `1.0.0+1`):

```bash
flutter build appbundle --release \
  --obfuscate --split-debug-info=build/symbols/<version>
```


## 5. Ofuscación y símbolos

`--obfuscate` renombra clases y funciones de Dart; los símbolos van a `build/symbols/<version>/` (ignorado por git).

- [ ] **Conservar los símbolos de cada build que subas** (copia de la carpeta o artefacto de CI). Sin ellos no se pueden leer sus stack traces.
- Leer un stack trace a mano: `flutter symbolize -i trace.txt -d build/symbols/<version>/app.android-arm64.symbols`.
- Los errores quedan en local; no se suben símbolos ni informes a servicios externos.

## 6. Versionado

- [ ] `version: X.Y.Z+N` en `app/pubspec.yaml`; `N` (versionCode) estrictamente creciente en cada subida a Play.
- [ ] Etiquetar el commit publicado (`vX.Y.Z`) y guardar junto a la etiqueta los símbolos de ese build.

## 7. Verificar

```bash
flutter build apk --release --obfuscate --split-debug-info=build/symbols/<version>
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

- [ ] El certificado corresponde a la clave del dueño, **nunca** a `CN=Android Debug` (un build de tienda solo se firma con la upload key).
- [ ] Sin `key.properties` y sin `-PallowDebugSigning=true`, el build falla con la lista de problemas.
- [ ] **Instalar el release y abrirlo en un dispositivo o emulador** antes de subirlo: los tests y el build de profile no pasan por R8. Si se queda en la pantalla de carga, mirar `adb logcat -s flutter:E` (un `NoSuchMethodError`/`ClassNotFoundException` es R8 quitando código que se llama por JNI).

### R8 y plugins con JNI
`shared_preferences_android` ≥ 2.5 y `path_provider_android` ≥ 2.3 llaman a Kotlin desde Dart por JNI y no traen reglas para R8. Sin las de `app/android/app/proguard-rules.pro` el release se queda en la pantalla de carga (visto el 19-oct-2026). Al añadir o actualizar un plugin, repetir la comprobación de arriba.

## 8. Pruebas locales con la clave de depuración (sin upload key)

Ya no hay ninguna clave de pruebas en el repositorio. Sin `app/android/key.properties`,
`-PallowDebugSigning=true` usa la configuración `debug` estándar de Android: la clave
local de `~/.android/debug.keystore`, fuera del repo. Android la genera si falta.
Solo sirve para pruebas locales y para `tool/qa/release_smoke.sh`.

```bash
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols/<version> -PallowDebugSigning=true
```

- Salida: `build/app/outputs/flutter-apk/app-{armeabi-v7a,arm64-v8a,x86_64}-release.apk`.
- Gradle avisa de la firma de depuración en cada build. Sin la propiedad y sin
  `key.properties`, un release falla. Un `key.properties` incompleto también falla.
- Si hay un `key.properties` completo, tiene prioridad la clave de subida real.
  Por eso el smoke test rechaza compilar mientras exista ese fichero. Se puede
  pasar al script un APK ya compilado para comprobarlo sin compilar de nuevo.
- Verifica con `apksigner verify --print-certs <apk>`: un APK de pruebas locales
  debe mostrar `CN=Android Debug`.
- La clave de depuración varía entre máquinas. Un cambio de firma impide actualizar
  una instalación anterior; exporta el progreso desde Ajustes antes de desinstalar
  e impórtalo después. Esto también afecta a las antiguas versiones de pruebas
  que usaban una clave compartida.
- Conserva los símbolos de los builds que necesites diagnosticar.

## 9. APK públicos

Los APK públicos se firman con la clave del dueño, que vive fuera del repositorio,
mediante `app/android/key.properties` (§1–2). No se distribuyen APK firmados con
claves de depuración.

Se ha retirado `release-apk.yml`: publicaba automáticamente APK de prueba y dependía
de una clave compartida en el repo. No hay publicación automática ni gestión de
secretos en Actions. El workflow `ci.yml` sigue analizando y probando el código.
La publicación de una versión se prepara y autoriza por separado.
