# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# CRITICAL: Keep FlutterFragmentActivity and all Fragment classes intact.
# local_auth checks instanceof FragmentActivity via reflection — if these
# are stripped or renamed, it throws no_fragment_activity even though the
# class is correct at compile time.
-keep class androidx.fragment.** { *; }
-keep class androidx.fragment.app.Fragment { *; }
-keep class androidx.fragment.app.FragmentActivity { *; }
-keep class androidx.fragment.app.FragmentManager { *; }
-keepclassmembers class androidx.fragment.app.** { *; }

# AppCompat — FlutterFragmentActivity extends AppCompatActivity
-keep class androidx.appcompat.** { *; }

# Biometric
-keep class androidx.biometric.** { *; }
-keepclassmembers class androidx.biometric.** { *; }

# local_auth plugin itself
-keep class io.flutter.plugins.localauth.** { *; }
-keepclassmembers class io.flutter.plugins.localauth.** { *; }

# PointyCastle
-keep class org.bouncycastle.** { *; }
-dontwarn org.bouncycastle.**

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# flutter_secure_storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# vibration
-keep class com.benjaminabel.vibration.** { *; }

# Kotlin
-keep class kotlin.** { *; }
-dontwarn kotlin.**
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-dontwarn org.slf4j.**
