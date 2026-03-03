plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.projects"
    compileSdk = flutter.compileSdkVersion

    defaultConfig {
        applicationId = "com.example.projects"
        minSdk = 23              // REQUIRED for Firebase Firestore
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Firebase BOM (keeps versions compatible)
    implementation(platform("com.google.firebase:firebase-bom:34.2.0"))

    // Firebase services you are using
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-firestore")
}

flutter {
    source = "../.."
}
