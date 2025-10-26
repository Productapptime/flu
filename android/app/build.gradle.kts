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
    ndkVersion = "27.0.12077973"  // ✅ Gerekli NDK sürümü (inappwebview 6.1.5 için)

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

        // Bu, dosya erişimi ve WebView için gerekli
        multiDexEnabled = true
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            signingConfig = signingConfigs.getByName("debug")
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
