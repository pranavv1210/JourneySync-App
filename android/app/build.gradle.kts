import java.util.Properties
import java.util.Base64

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
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
val auth0DomainValue =
    (dartDefineMap["AUTH0_DOMAIN"] ?: project.findProperty("AUTH0_DOMAIN")?.toString() ?: "")
        .trim()
val auth0SchemeValue =
    (dartDefineMap["AUTH0_SCHEME"] ?: project.findProperty("AUTH0_SCHEME")?.toString() ?: "https")
        .trim()

android {
    namespace = "com.example.journeysync"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.journeysync"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders += mapOf(
            "auth0Domain" to auth0DomainValue,
            "auth0Scheme" to if (auth0SchemeValue.isNotEmpty()) auth0SchemeValue else "https",
        )
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
                throw GradleException(
                    "Missing Android release signing config. " +
                        "Create android/key.properties (see android/key.properties.example)."
                )
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
