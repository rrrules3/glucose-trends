import java.util.Properties
import java.io.FileInputStream

// Upload-signing credentials live outside version control. Without this file
// the release build falls back to debug signing, so `flutter run --release`
// keeps working for anyone who clones the repo — but such a build can never be
// uploaded to Play.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasUploadKey = keystorePropertiesFile.exists()
if (hasUploadKey) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.glucosetrends.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.glucosetrends.app"
        // Raised for the health plugin, which needs API 26 for Health Connect.
        // That is Android 8.0 (2017), so the coverage cost is negligible;
        // flutter_secure_storage's own floor of 23 is already below it.
        minSdk = maxOf(flutter.minSdkVersion, 26)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasUploadKey) {
            create("upload") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasUploadKey) {
                signingConfigs.getByName("upload")
            } else {
                // Debug-signed: runnable locally, rejected by Play.
                signingConfigs.getByName("debug")
            }
            // R8 shrinking is deliberately left off. It can strip
            // reflection-reached plugin code and produce crashes that surface
            // only in release, and nothing here has been tested with it on.
            // If you enable it, install the resulting release build on a real
            // device and exercise Health Connect and CSV import before
            // shipping — those are the paths most likely to break.
        }
    }
}

flutter {
    source = "../.."
}
