# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Play Core (referenced by Flutter embedding but optional)
-dontwarn com.google.android.play.core.**

# App
-keep class ir.hmrbot.app.** { *; }

# Google Play Services / Sign-In
# Classes are loaded via reflection by the GMS framework; stripping them
# causes silent sign-in failures that only appear in release builds.
-keep class com.google.android.gms.** { *; }
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }
-dontwarn com.google.android.gms.**

# sqflite
# SqflitePlugin registers itself via reflection on older AGP versions.
-keep class com.tekartik.sqflite.** { *; }
-dontwarn com.tekartik.sqflite.**

# shared_preferences
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-dontwarn io.flutter.plugins.sharedpreferences.**

# AndroidX — kept broadly because many plugins depend on androidx internals
# accessed via reflection (e.g. lifecycle, activity result APIs).
-keep class androidx.lifecycle.** { *; }
-keep class androidx.activity.** { *; }
-keep class androidx.fragment.** { *; }
-dontwarn androidx.**

# url_launcher / Custom Tabs
-keep class androidx.browser.customtabs.** { *; }
-dontwarn androidx.browser.**

# Sentry — crash reporting. Sentry uses reflection to read stack frames and
# device metadata; obfuscating these classes breaks crash reports entirely.
-keep class io.sentry.** { *; }
-keep class io.sentry.android.** { *; }
-dontwarn io.sentry.**
# Preserve original class/method names so Sentry stack traces are readable.
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# connectivity_plus — uses Android NetworkCallback APIs via reflection.
-keep class dev.fluttercommunity.plus.connectivity.** { *; }
-dontwarn dev.fluttercommunity.plus.connectivity.**

# OkHttp / Okio (transitive dep of some plugins; safe to suppress warnings)
-dontwarn okhttp3.**
-dontwarn okio.**
