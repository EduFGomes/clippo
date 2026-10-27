plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.clippoapp.clippo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.clippoapp.clippo"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // O detector de pessoas (assets/efficientdet_lite0.tflite) é lido direto do APK: não pode
    // ir comprimido.
    androidResources {
        noCompress += "tflite"
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Câmera (CameraX): abre a câmera uma vez e entrega vários fluxos (imagem na tela, quadros
    // para análise e, depois, o vídeo do buffer). Ver kotlin/.../camera/README.md.
    val cameraX = "1.6.2"
    implementation("androidx.camera:camera-camera2:$cameraX")
    implementation("androidx.camera:camera-lifecycle:$cameraX")
    implementation("androidx.camera:camera-view:$cameraX")

    // Pontos do corpo (ML Kit Pose, BlazePose com 33 pontos), com o modelo embutido no app para
    // funcionar sem internet (R8). O Google só publica versões beta desde a 17.0.0, de 2020.
    // 🟡 Os dois modelos ficam até a medição a 8 m decidir qual usar: o "accurate" é mais
    // preciso e mais pesado.
    val mlKitPose = "18.0.0-beta5"
    implementation("com.google.mlkit:pose-detection:$mlKitPose")
    implementation("com.google.mlkit:pose-detection-accurate:$mlKitPose")

    // Detector de pessoas (MediaPipe Tasks, Apache 2.0) para o modo várias pessoas: acha cada
    // pessoa no quadro e um ML Kit para cada uma lê a pose do recorte dela. 🟡 Em teste; ver
    // kotlin/.../camera/MultiPersonAnalyzer.kt. O modelo (EfficientDet-Lite0, 4,6 MB) está em
    // src/main/assets/, baixado de storage.googleapis.com/mediapipe-models.
    implementation("com.google.mediapipe:tasks-vision:0.10.35")
}
