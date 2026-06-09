# Flutter-specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Prevent R8 from stripping away native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# If you use the crypto package or similar hashing libraries
-keep class org.bouncycastle.** { *; }
-dontwarn org.bouncycastle.**

# If you use package_info_plus
-keep class com.baseflow.packageinfo.** { *; }

# Play Core (deferred components / split install) — not used but referenced by Flutter embedding
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }