# R8 rules for the release build.
#
# shared_preferences_android >= 2.5 and path_provider_android >= 2.3 call their
# Kotlin classes from Dart through JNI (package:jni). R8 cannot see those calls,
# so it strips or renames the methods and the release app stops on the splash
# screen with NoSuchMethodError (found 2026-10-19 on the emulator). Keep the
# plugin classes and the Kotlin types that appear in their JNI signatures.
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class io.flutter.plugins.pathprovider.** { *; }
-keep class com.github.dart_lang.jni.** { *; }
# The JNI bridge drives suspend functions from native code, so it looks up
# coroutine machinery (e.g. kotlin.coroutines.intrinsics.CoroutineSingletons)
# by name.
-keep class kotlin.coroutines.** { *; }
-keep class kotlinx.coroutines.** { *; }
-keep class kotlin.Result { *; }
-keep class kotlin.Result$* { *; }
-keep class kotlin.Unit { *; }
-keep class kotlin.jvm.functions.** { *; }
