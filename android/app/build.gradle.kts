import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Kunci rilis dibaca dari android/key.properties (tidak ikut git).
// Di CI file ini ditulis dari GitHub Secrets sebelum build.
//
// Ini bukan sekadar formalitas Play Store: tanpa kunci tetap, tiap build CI
// memakai kunci debug yang dibuat ulang di runner baru, sehingga APK versi
// berikutnya DITOLAK memasang di atas versi sebelumnya
// (INSTALL_FAILED_UPDATE_INCOMPATIBLE) dan tombol pembaruan jadi percuma.
val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val adaKunciRilis = keyProps.getProperty("storeFile") != null

android {
    namespace = "id.gudang.tiket_gudang"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "id.gudang.tiket_gudang"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (adaKunciRilis) {
            create("release") {
                storeFile = rootProject.file(keyProps.getProperty("storeFile"))
                storePassword = keyProps.getProperty("storePassword")
                keyAlias = keyProps.getProperty("keyAlias")
                keyPassword = keyProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Tanpa key.properties tetap pakai kunci debug supaya
            // `flutter run --release` di mesin developer tetap jalan.
            signingConfig = if (adaKunciRilis) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
