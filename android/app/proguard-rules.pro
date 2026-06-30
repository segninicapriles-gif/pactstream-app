# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Supabase / GoTrue
-keep class io.supabase.** { *; }
-dontwarn io.supabase.**

# Sentry
-keep class io.sentry.** { *; }
-dontwarn io.sentry.**

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}
