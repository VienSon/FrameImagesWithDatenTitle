import java.io.File

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

fun manifestPackageName(manifestFile: File): String? {
    if (!manifestFile.exists()) return null
    val content = manifestFile.readText()
    val match = Regex("""package\s*=\s*"([^"]+)"""").find(content)
    return match?.groupValues?.getOrNull(1)
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
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    pluginManager.withPlugin("com.android.library") {
        val androidExt = extensions.findByName("android") ?: return@withPlugin
        val getNamespace = androidExt.javaClass.methods.firstOrNull { method ->
            method.name == "getNamespace" && method.parameterCount == 0
        } ?: return@withPlugin
        val setNamespace = androidExt.javaClass.methods.firstOrNull { method ->
            method.name == "setNamespace" &&
                method.parameterCount == 1 &&
                method.parameterTypes[0] == String::class.java
        } ?: return@withPlugin

        val currentNamespace = getNamespace.invoke(androidExt) as? String
        if (!currentNamespace.isNullOrBlank()) return@withPlugin

        val manifestFile = file("src/main/AndroidManifest.xml")
        val manifestPackage = manifestPackageName(manifestFile) ?: return@withPlugin
        setNamespace.invoke(androidExt, manifestPackage)
    }
}

subprojects {
    pluginManager.withPlugin("org.jetbrains.kotlin.android") {
        tasks.configureEach {
            if (name.startsWith("compile") && name.contains("Kotlin")) {
                val kotlinOptions = javaClass.methods.firstOrNull { method ->
                    method.name == "getKotlinOptions" && method.parameterCount == 0
                }?.invoke(this) ?: return@configureEach
                val variantName = name.removePrefix("compile").removeSuffix("Kotlin")
                val javaTaskName = "compile${variantName}JavaWithJavac"
                val javaTask = project.tasks.findByName(javaTaskName)
                val javaTargetValue = javaTask?.javaClass?.methods
                    ?.firstOrNull { method ->
                        method.name == "getTargetCompatibility" && method.parameterCount == 0
                    }
                    ?.invoke(javaTask)
                    ?.toString()
                    ?.lowercase()
                val kotlinJvmTarget = when {
                    javaTargetValue == null -> "1.8"
                    javaTargetValue.contains("21") -> "21"
                    javaTargetValue.contains("17") -> "17"
                    javaTargetValue.contains("11") -> "11"
                    else -> "1.8"
                }

                kotlinOptions.javaClass.methods.firstOrNull { method ->
                    method.name == "setJvmTarget" &&
                        method.parameterCount == 1 &&
                        method.parameterTypes[0] == String::class.java
                }?.invoke(kotlinOptions, kotlinJvmTarget)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
