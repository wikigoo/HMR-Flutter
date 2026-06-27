val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Force every Android module (app + plugins such as :jni from sentry_flutter) onto the
// NDK that is actually installed locally (30.0.14904198), so a plugin pinning a different
// NDK version (e.g. 28.2.13676358) does not trigger a fresh ~1GB NDK download.
// Uses plugins.withId (fires when the Android plugin is applied) instead of afterEvaluate,
// which would run too late here because of the evaluationDependsOn(":app") block above.
subprojects {
    val forceNdkVersion = "30.0.14904198"
    val forceBuildTools = "36.1.0"
    val applyForced: () -> Unit = {
        (extensions.findByName("android") as? com.android.build.gradle.BaseExtension)?.apply {
            ndkVersion = forceNdkVersion
            buildToolsVersion = forceBuildTools
            compileSdkVersion(36)
        }
        // Some plugins (e.g. sentry_flutter) still request Kotlin languageVersion 1.6, which the
        // Kotlin 2.3.20 compiler no longer supports. Force every Kotlin compile task to 2.0.
        tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java).configureEach {
            compilerOptions {
                languageVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_2_0)
                apiVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_2_0)
            }
        }
    }
    // Run AFTER each plugin's own build script has set its (often outdated) versions, so our
    // values win. If the project is already evaluated, apply immediately.
    if (state.executed) applyForced() else afterEvaluate { applyForced() }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
