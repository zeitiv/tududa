# Keep kotlinx-serialization generated serializers and Tink's protobuf-lite classes.
-keepattributes *Annotation*, InnerClasses
-keep,includedescriptorclasses class com.tududi.core.**$$serializer { *; }
-keepclassmembers class com.tududi.core.** {
    *** Companion;
}
-keepclasseswithmembers class com.tududi.core.** {
    kotlinx.serialization.KSerializer serializer(...);
}
-keep class * extends com.google.crypto.tink.shaded.protobuf.GeneratedMessageLite { *; }
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**
