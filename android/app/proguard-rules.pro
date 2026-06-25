# Flutter ProGuard Rules
# Keep Flutter engine classes
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep annotations
-keepattributes *Annotation*

# Keep Mobile Scanner (camera barcode scanning)
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Keep shared_preferences
-keep class androidx.datastore.** { *; }

# Suppress warnings for missing classes that are unused
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**

# Play Core (referenced by Flutter engine but not used in this app)
-dontwarn com.google.android.play.core.**
