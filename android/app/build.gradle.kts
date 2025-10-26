plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter Gradle Plugin must come last
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.hello_flutter"

    // 🔧 Flutter değişkenlerinden bağımsız sabitle
    compileSdk = 34
    ndkVersion = "27.0.12077973"  // ✅ inappwebview 6.1.5 için gerekli NDK

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.hello_flutter"
        minSdk = 21
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"

        // 📂 WebView & dosya erişimi için
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // 🚫 Kaynak ve kod küçültme tamamen kapalı
            isMinifyEnabled = false
            isShrinkResources = false     // 👈 Bu satır hatayı %100 çözer
            signingConfig = signingConfigs.getByName("debug")
        }
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    // 🔒 WebView dosya erişimi sorunlarını önlemek için
    packaging {
        resources {
            excludes += "META-INF/DEPENDENCIES"
            excludes += "META-INF/LICENSE"
            excludes += "META-INF/LICENSE.txt"
            excludes += "META-INF/NOTICE"
            excludes += "META-INF/NOTICE.txt"
        }
    }
}

flutter {
    source = "../.."
}
