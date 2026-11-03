plugins {
    // Google services Gradle plugin (kept separate so app module can apply it)
    id("com.google.gms.google-services") version "4.4.3" apply false
}

// Central repository definitions for all subprojects.
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// (Optional) toolchain / Java compatibility hints could go here if non-standard.

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    // Ensure app evaluated early for plugin version alignment
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
