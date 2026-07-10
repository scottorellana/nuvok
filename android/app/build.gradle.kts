plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeystorePath = System.getenv("NUVOK_KEYSTORE")
val releaseKeyAlias = System.getenv("NUVOK_KEY_ALIAS")
val releaseStorePassword = System.getenv("NUVOK_STORE_PASSWORD")
val releaseKeyPassword = System.getenv("NUVOK_KEY_PASSWORD") ?: releaseStorePassword
val hasReleaseSigning = !releaseKeystorePath.isNullOrBlank() &&
    !releaseKeyAlias.isNullOrBlank() &&
    !releaseStorePassword.isNullOrBlank() &&
    !releaseKeyPassword.isNullOrBlank() &&
    file(releaseKeystorePath!!).exists()

android {
    namespace = "org.nuvok.nuvok"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications usa java.time → desugaring obligatorio.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        // Must remain stable so installed Prepper Pad builds can update to NUVOK.
        applicationId = "com.prepperpad.prepper_pad"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("releaseEnv") {
                storeFile = file(releaseKeystorePath!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            // Production builds should set NUVOK_KEYSTORE,
            // NUVOK_KEY_ALIAS and NUVOK_STORE_PASSWORD. Local
            // unsigned-key builds keep the debug fallback so QA APK generation
            // still works without checking secrets into the repo.
            signingConfig = signingConfigs.getByName(
                if (hasReleaseSigning) "releaseEnv" else "debug"
            )
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
