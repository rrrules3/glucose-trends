allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// Pin every plugin module to the SDK platform this project actually compiles
// against.
//
// `flutter_secure_storage` hardcodes `compileSdk = 37`, and AGP turns that into
// the platform hash `android-37`. Google no longer publishes a plain
// `android-37` — the packages are `android-37.0`, `android-37.1`, and so on —
// so that lookup fails with "Failed to find target with hash string
// 'android-37'". Compiling those modules against 36 resolves it; nothing here
// uses an API newer than 36, and the app's own `targetSdk` is unaffected, so
// this does not change runtime behaviour or the Play API-level requirement.
//
// `withGroovyBuilder` invokes the extension dynamically, which avoids putting
// the Android Gradle Plugin's types on the root build script's classpath.
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.withGroovyBuilder {
            "compileSdkVersion"(36)
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
