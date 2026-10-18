# App-level R8 rules. Library rules live in android/tududi_core/consumer-rules.pro.
-keepattributes *Annotation*, InnerClasses
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**
-dontwarn com.google.android.play.core.**
