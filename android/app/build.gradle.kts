import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "zack20136.com.quill_lock_diary"
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
        applicationId = "zack20136.com.quill_lock_diary"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 30
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val releaseKeystorePropertiesFile = rootProject.file("key.properties")
    val releaseKeystoreProperties = Properties()
    if (releaseKeystorePropertiesFile.exists()) {
        releaseKeystorePropertiesFile.inputStream().use(releaseKeystoreProperties::load)
    }
    val releaseSigningKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    val hasReleaseSigningConfig = releaseSigningKeys.all { key ->
        releaseKeystoreProperties.getProperty(key)?.isNotBlank() == true
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigningConfig) {
                storeFile = file(releaseKeystoreProperties.getProperty("storeFile"))
                storePassword = releaseKeystoreProperties.getProperty("storePassword")
                keyAlias = releaseKeystoreProperties.getProperty("keyAlias")
                keyPassword = releaseKeystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigningConfig) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }

    gradle.taskGraph.whenReady {
        val releaseTaskRequested = allTasks.any { task ->
            task.path == ":app:assembleRelease" ||
                task.path == ":app:bundleRelease" ||
                task.name.contains("Release")
        }
        if (releaseTaskRequested && !hasReleaseSigningConfig) {
            throw GradleException(
                "Release signing requires android/key.properties with " +
                    releaseSigningKeys.joinToString(", ") +
                    ". Debug signing is not allowed for release builds.",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.biometric:biometric:1.1.0")
    implementation("io.realm:realm-android-library:10.19.0")
}
