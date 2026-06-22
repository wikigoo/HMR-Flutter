# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Play Core (referenced by Flutter embedding but optional)
-dontwarn com.google.android.play.core.**

# App
-keep class ir.hmrbot.app.** { *; }
