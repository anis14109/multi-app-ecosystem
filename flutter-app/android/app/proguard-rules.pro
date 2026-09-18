# Flutter-specific proguard rules
-dontwarn io.flutter.plugin.**
-dontwarn android.**

-if class * implements io.flutter.embedding.engine.plugins.FlutterPlugin
-keep,allowshrinking,allowobfuscation class <1>