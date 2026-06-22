import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// ---------------------------------------------------------------------------
// Signing config resolution — two paths, no secrets ever in source control:
//
//   CI path  : env vars injected by GitHub Actions (HMR_KEYSTORE_PATH, etc.)
//   Local path: android/key.properties (gitignored, developer's machine only)
//
// If neither is present the signingConfig block is left unconfigured so that
// debug builds continue to work without a keystore.
// ---------------------------------------------------------------------------
fun signingValue(envKey: String, propKey: String, localProps: Properties): String? =
    System.getenv(envKey) ?: localProps[propKey] as String?

val localProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

val releaseAlias    = signingValue("HMR_KEY_ALIAS",      "keyAlias",    localProps)
val releaseKeyPwd   = signingValue("HMR_KEY_PASSWORD",   "keyPassword", localProps)
val releaseStorePwd = signingValue("HMR_STORE_PASSWORD", "storePassword", localProps)
// HMR_KEYSTORE_PATH is an absolute path written by CI; local key.properties
// uses a path relative to android/app/ (the module root for file()).
val releaseJksPath  = System.getenv("HMR_KEYSTORE_PATH")
    ?: (localProps["storeFile"] as String?)

val hasSigningConfig = listOf(releaseAlias, releaseKeyPwd, releaseStorePwd, releaseJksPath)
    .all { !it.isNullOrBlank() }

android {
    namespace = "ir.hmrbot.app"
    compileSdk = 36
    ndkVersion = "30.0.14904198"
    buildToolsVersion = "36.1.0"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    if (hasSigningConfig) {
        signingConfigs {
            create("release") {
                keyAlias      = releaseAlias
                keyPassword   = releaseKeyPwd
                storeFile     = file(releaseJksPath!!)
                storePassword = releaseStorePwd
            }
        }
    }

    defaultConfig {
        applicationId = "ir.hmrbot.app"
        minSdk = 21
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            if (hasSigningConfig) {
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
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
