plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeystorePath = System.getenv("PREPPER_PAD_KEYSTORE")
val releaseKeyAlias = System.getenv("PREPPER_PAD_KEY_ALIAS")
val releaseStorePassword = System.getenv("PREPPER_PAD_STORE_PASSWORD")
val releaseKeyPassword = System.getenv("PREPPER_PAD_KEY_PASSWORD") ?: releaseStorePassword
val hasReleaseSigning = !releaseKeystorePath.isNullOrBlank() &&
    !releaseKeyAlias.isNullOrBlank() &&
    !releaseStorePassword.isNullOrBlank() &&
    !releaseKeyPassword.isNullOrBlank() &&
    file(releaseKeystorePath!!).exists()

android {
    namespace = "com.prepperpad.prepper_pad"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
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
            // Production builds should set PREPPER_PAD_KEYSTORE,
            // PREPPER_PAD_KEY_ALIAS and PREPPER_PAD_STORE_PASSWORD. Local
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
