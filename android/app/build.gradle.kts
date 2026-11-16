plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.mattathiasa.routine_planner"
    // flutter_local_notifications requires compileSdk 37+ and core library
    // desugaring; flutter.compileSdkVersion doesn't default this high yet.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.mattathiasa.routine_planner"
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

    // Release signing comes from the environment, never from a committed
    // file: set RP_KEYSTORE_PATH, RP_KEYSTORE_PASSWORD, RP_KEY_ALIAS and
    // RP_KEY_PASSWORD before `flutter build apk --release`. Without them
    // the release build falls back to debug signing so local smoke builds
    // and un-secreted CI keep working (the APK is then NOT distributable).
    val keystorePath = System.getenv("RP_KEYSTORE_PATH")
    if (keystorePath != null) {
        signingConfigs.create("release") {
            storeFile = file(keystorePath)
            storePassword = System.getenv("RP_KEYSTORE_PASSWORD")
            keyAlias = System.getenv("RP_KEY_ALIAS")
            keyPassword = System.getenv("RP_KEY_PASSWORD")
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePath != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
