import java.util.Properties
import java.util.Base64
import groovy.json.JsonSlurper

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

fun encodeDartDefinesFromJson(file: File): String {
    val parsed = JsonSlurper().parse(file) as? Map<*, *> ?: return ""
    return parsed.entries
        .mapNotNull { entry ->
            val key = entry.key?.toString()?.trim().orEmpty()
            val value = entry.value?.toString()?.trim().orEmpty()
            if (key.isEmpty() || value.isEmpty()) {
                null
            } else {
                val raw = "$key=$value"
                Base64.getUrlEncoder()
                    .withoutPadding()
                    .encodeToString(raw.toByteArray(Charsets.UTF_8))
            }
        }
        .joinToString(",")
}

if (!project.hasProperty("dart-defines")) {
    val localDartDefineFile = rootProject.file("../dart_defines.local.json")
    if (localDartDefineFile.exists()) {
        val encodedDartDefines = encodeDartDefinesFromJson(localDartDefineFile)
        if (encodedDartDefines.isNotEmpty()) {
            extensions.extraProperties["dart-defines"] = encodedDartDefines
            project.logger.lifecycle(
                "Using dart-defines from ${localDartDefineFile.name} for Android build."
            )
        }
    }
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}
val hasReleaseSigningConfig =
    !keystoreProperties.getProperty("storeFile").isNullOrBlank() &&
    !keystoreProperties.getProperty("storePassword").isNullOrBlank() &&
    !keystoreProperties.getProperty("keyAlias").isNullOrBlank() &&
    !keystoreProperties.getProperty("keyPassword").isNullOrBlank()
val isReleaseTaskRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
val dartDefineMap = buildMap {
    val raw = project.findProperty("dart-defines")?.toString()?.trim().orEmpty()
    if (raw.isNotEmpty()) {
        raw.split(",").forEach { encoded ->
            runCatching {
                val decoded =
                    String(Base64.getUrlDecoder().decode(encoded), Charsets.UTF_8)
                val separator = decoded.indexOf('=')
                if (separator > 0) {
                    put(
                        decoded.substring(0, separator),
                        decoded.substring(separator + 1),
                    )
                }
            }
        }
    }
}
android {
    namespace = "com.example.journeysync"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.journeysync.app"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigningConfig) {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (!hasReleaseSigningConfig && isReleaseTaskRequested) {
                // throw GradleException(
                //     "Missing Android release signing config. " +
                //         "Create android/key.properties (see android/key.properties.example)."
                // )
            }
            signingConfig =
                if (hasReleaseSigningConfig) {
                    signingConfigs.getByName("release")
                } else {
                    // Keep debug/local builds usable when release task is not requested.
                    signingConfigs.getByName("debug")
                }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
