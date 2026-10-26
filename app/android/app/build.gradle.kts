import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties().apply {
    if (keyPropertiesFile.exists()) keyPropertiesFile.inputStream().use { load(it) }
}
val hasReleaseKey = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    .all { !keyProperties.getProperty(it).isNullOrBlank() }

// Release guard (docs/release-signing.md): a release build needs the upload
// key in android/key.properties. `-PallowDebugSigning=true` signs it with the
// machine's standard Android debug key instead: ONLY for local tests and
// the release smoke test, never for public distribution.
val allowDebugSigning =
    (project.findProperty("allowDebugSigning") as String?)?.toBoolean() == true

val releaseProblems: List<String> = buildList {
    if (keyPropertiesFile.exists() && !hasReleaseKey) {
        add("android/key.properties must define storeFile, storePassword, keyAlias and keyPassword.")
    }
    if (!hasReleaseKey && !allowDebugSigning) {
        add(
            "android/key.properties is missing, so there is no release key. " +
                "Private test builds only: add -PallowDebugSigning=true.",
        )
    }
}

fun releaseFailure(): GradleException = GradleException(
    "\n==============================================================\n" +
        " Refusing to build a RELEASE:\n" +
        releaseProblems.joinToString("\n") { " - $it" } +
        "\n See docs/release-signing.md for the exact commands.\n" +
        "==============================================================",
)

// Fail before anything is compiled when a release task was requested...
if (releaseProblems.isNotEmpty() &&
    gradle.startParameter.taskNames.any { it.contains("Release") }
) {
    throw releaseFailure()
}

android {
    namespace = "es.leyalblanco.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "es.leyalblanco.app"
        minSdk = maxOf(flutter.minSdkVersion, 21)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // `android/key.properties` is gitignored and holds the upload keystore.
    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = rootProject.file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else if (allowDebugSigning) {
                logger.warn(
                    "\n==============================================================\n" +
                        " -PallowDebugSigning=true: the RELEASE build is signed\n" +
                        " with the DEBUG key. Private test builds only.\n" +
                        "==============================================================",
                )
                signingConfigs.getByName("debug")
            } else {
                null // the release guard fails the build
            }
            // JNI-based plugins need keep rules (see proguard-rules.pro).
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

// ...and as a backstop when a release variant is built through another entry
// point (an IDE, a task name without "Release").
tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    val failure = if (releaseProblems.isEmpty()) null else releaseFailure().message
    doFirst {
        if (failure != null) throw GradleException(failure)
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
