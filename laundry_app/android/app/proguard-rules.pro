# google_mlkit_text_recognition solo se usa para OCR de carnet (español), pero la
# librería referencia internamente los recognizers opcionales de otros idiomas
# (chino, japonés, coreano, devanagari) que no se incluyen como dependencia.
# Sin estas reglas, R8 falla el build de release por "Missing classes".
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions

# ML Kit (detección de caras en vivo): R8 rompía la conversión de frames
# (NullPointerException en mlkit_vision_common.zzmj.<init>).
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_** { *; }
-keep class com.google_mlkit_commons.** { *; }
-keep class com.google_mlkit_face_detection.** { *; }

# Referencia opcional a firebase-iid (modelos remotos de ML Kit, no usados).
-dontwarn com.google.firebase.iid.**
-dontwarn com.google.mlkit.linkfirebase.**

# tflite_flutter (comparación de rostros)
-keep class org.tensorflow.** { *; }
-dontwarn org.tensorflow.lite.gpu.**
