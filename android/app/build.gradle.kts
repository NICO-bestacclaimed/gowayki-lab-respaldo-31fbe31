import com.google.firebase.crashlytics.buildtools.gradle.CrashlyticsExtension
import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseProperties = Properties()
val releasePropertiesFile = rootProject.file("key.properties")
if (releasePropertiesFile.exists()) {
    releasePropertiesFile.inputStream().use { releaseProperties.load(it) }
}
val releaseSigningReady = listOf("storePassword", "keyPassword", "keyAlias", "storeFile")
    .all { !releaseProperties.getProperty(it).isNullOrBlank() } &&
    releaseProperties.getProperty("storeFile")?.let { file(it).isFile } == true

android {
    namespace = "pe.edu.tecsup.gowayki_lab"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "pe.edu.tecsup.gowayki_lab"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningReady) {
            create("release") {
                keyAlias = releaseProperties.getProperty("keyAlias")
                keyPassword = releaseProperties.getProperty("keyPassword")
                storeFile = file(releaseProperties.getProperty("storeFile"))
                storePassword = releaseProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}

// Builds remain local: uploading mappings/symbols needs a separate explicit action.
android.buildTypes.configureEach {
    configure<CrashlyticsExtension> {
        mappingFileUploadEnabled = false
        nativeSymbolUploadEnabled = false
    }
}

val validateGoWaykiReleaseSigning = tasks.register("validateGoWaykiReleaseSigning") {
    doLast {
        check(releaseSigningReady) {
            "Release requires android/key.properties and its existing keystore. Run tool/create_release_keystore.py locally; never use a debug signature for release."
        }
    }
}
tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    dependsOn(validateGoWaykiReleaseSigning)
}
