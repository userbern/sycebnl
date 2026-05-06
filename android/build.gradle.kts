allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

subprojects {
    project.layout.buildDirectory.value(project.layout.projectDirectory.dir("build"))
    project.evaluationDependsOn(":app")
}

gradle.projectsEvaluated {
    subprojects {
        layout.buildDirectory.value(layout.projectDirectory.dir("build"))
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
