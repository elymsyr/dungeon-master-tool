# Flutter core
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class * extends io.flutter.embedding.android.FlutterActivity { *; }
-dontwarn io.flutter.embedding.**

# Plugins (desktop_multi_window, supabase, soloud, window_manager, etc.)
-keep class com.flutter.plugin.** { *; }
-dontwarn com.flutter.plugin.**

# Supabase / OkHttp / Gson (transitive)
-keep class io.supabase.** { *; }
-dontwarn io.supabase.**
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Kotlin coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembers class kotlinx.coroutines.** {
    volatile <fields>;
}

# Keep enum values for plugins relying on reflection
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep R class
-keep class **.R$* { *; }
