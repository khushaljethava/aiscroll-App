# Project-specific ProGuard / R8 rules for release builds.
#
# These supplement the defaults in `proguard-android-optimize.txt`. Any
# library that uses reflection, dynamic dispatch, or generated code
# needs to be kept.

# ---------------------------------------------------------------------------
# Flutter — keep the embedding so the engine can look it up by name.
# ---------------------------------------------------------------------------
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.editing.** { *; }
-dontwarn io.flutter.embedding.**

# ---------------------------------------------------------------------------
# Firebase — Firestore + Auth + App Check + Messaging all use reflection
# for serialisation / native interop.
# ---------------------------------------------------------------------------
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ---------------------------------------------------------------------------
# Google Mobile Ads — native ad templates load Java classes by name.
# ---------------------------------------------------------------------------
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# ---------------------------------------------------------------------------
# Play Integrity — App Check provider in release builds.
# ---------------------------------------------------------------------------
-keep class com.google.android.play.core.integrity.** { *; }
-dontwarn com.google.android.play.core.**

# ---------------------------------------------------------------------------
# Annotations / desugaring (flutter_local_notifications uses java.time).
# ---------------------------------------------------------------------------
-keep class j$.time.** { *; }
-dontwarn j$.time.**

# ---------------------------------------------------------------------------
# flutter_local_notifications — the boot receiver and scheduled-action
# receivers are referenced by name from AndroidManifest.xml; R8 doesn't
# see those string references and would otherwise strip them, breaking
# reboot rescheduling and the foreground news banner.
# ---------------------------------------------------------------------------
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# ---------------------------------------------------------------------------
# WebView (used by Google Mobile Ads native template renderer).
# ---------------------------------------------------------------------------
-keepclassmembers class * extends android.webkit.WebViewClient {
    public void *(android.webkit.WebView, java.lang.String, android.graphics.Bitmap);
    public boolean *(android.webkit.WebView, java.lang.String);
}

# ---------------------------------------------------------------------------
# Suppress Play Core "missing class" warnings — these are referenced by
# flutter_play_store_split for deferred component loading; we don't use
# deferred components, but R8 still inspects the references.
# ---------------------------------------------------------------------------
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
