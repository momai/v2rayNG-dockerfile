plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.v2ray.ang"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.v2ray.ang"
        minSdk = 21
        targetSdk = 34
        versionCode = 583
        versionName = "1.8.38"
        multiDexEnabled = true
        splits {
            abi {
                isEnable = true
                include(
                    "arm64-v8a",
                    "armeabi-v7a",
                    "x86_64",
                    "x86"
                )
                isUniversalApk = true
            }
        }
        // Добавляем resValue для vas3k_subscription_url
        resValue("string", "vas3k_subscription_url", project.properties["myArgument"] as String? ?: "VAS3K_SUB_URL")
        
        // Добавляем BuildConfig поле
        buildConfigField("String", "VAS3K_SUB_URL", "\"${project.properties["myArgument"] ?: "VAS3K_SUB_URL"}\"")

    }

    signingConfigs {
        create("release") {
            storeFile = file("release_keystore")
            storePassword = "123123"
            keyAlias = "123"
            keyPassword = "123123"
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }
    buildTypes {
        release {
            isMinifyEnabled = false
            signingConfig = signingConfigs.getByName("release")
        }
        debug {
            isMinifyEnabled = false

        }
    }

    sourceSets {
        getByName("main") {
            jniLibs.srcDirs("libs")
        }
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_1_8.toString()
    }

    applicationVariants.all {
        val variant = this
        val versionCodes =
            mapOf("armeabi-v7a" to 4, "arm64-v8a" to 4, "x86" to 4, "x86_64" to 4, "universal" to 4)

        variant.outputs
            .map { it as com.android.build.gradle.internal.api.ApkVariantOutputImpl }
            .forEach { output ->
                val abi = if (output.getFilter("ABI") != null)
                    output.getFilter("ABI")
                else
                    "universal"

                output.outputFileName = "v2rayNG_${variant.versionName}_${abi}.apk"
                if (versionCodes.containsKey(abi)) {
                    output.versionCodeOverride = (1000000 * versionCodes[abi]!!).plus(variant.versionCode)
                } else {
                    return@forEach
                }
            }
    }

    buildFeatures {
        viewBinding = true
        buildConfig = true
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }
}

dependencies {
    implementation(fileTree(mapOf("dir" to "libs", "include" to listOf("*.aar", "*.jar"))))
    testImplementation(libs.junit)

    implementation(libs.flexbox)
    // Androidx
    implementation(libs.constraintlayout)
    implementation(libs.legacy.support.v4)
    implementation(libs.appcompat)
    implementation(libs.material)
    implementation(libs.cardview)
    implementation(libs.preference.ktx)
    implementation(libs.recyclerview)
    implementation(libs.fragment.ktx)
    implementation(libs.multidex)
    implementation(libs.viewpager2)

    // Androidx ktx
    implementation(libs.activity.ktx)
    implementation(libs.lifecycle.viewmodel.ktx)
    implementation(libs.lifecycle.livedata.ktx)
    implementation(libs.lifecycle.runtime.ktx)

    //kotlin
    implementation(libs.kotlin.reflect)
    implementation(libs.kotlinx.coroutines.core)
    implementation(libs.kotlinx.coroutines.android)

    implementation(libs.mmkv.static)
    implementation(libs.gson)
    implementation(libs.rxjava)
    implementation(libs.rxandroid)
    implementation(libs.rxpermissions)
    implementation(libs.toastcompat)
    implementation(libs.editorkit)
    implementation(libs.language.base)
    implementation(libs.language.json)
    implementation(libs.quickie.bundled)
    implementation(libs.core)
    implementation(libs.work.runtime.ktx)
    implementation(libs.work.multiprocess)
}

val myArgument: String? by project

val preAssembleRelease by tasks.registering {
    doLast {
        println("==== EXECUTING PRE ASSEMBLE RELEASE TASK ====")
        println("myArgument value: $myArgument")
        
        val stringsFile = file("src/main/res/values/strings.xml")
        println("strings.xml exists: ${stringsFile.exists()}")
        println("strings.xml path: ${stringsFile.absolutePath}")
        println("Original strings.xml content:")
        println(stringsFile.readText())
        
        if (!myArgument.isNullOrBlank()) {
            val newContent = stringsFile.readText().replace("VAS3K_SUB_URL", myArgument!!)
            stringsFile.writeText(newContent)
            println("Replacement successful")
            println("Updated strings.xml content:")
            println(newContent)
        } else {
            println("myArgument is null or blank, skipping replacement")
        }
    }
}

val postAssembleRelease by tasks.registering {
    doLast {
        println("==== EXECUTING POST ASSEMBLE RELEASE TASK ====")
        val stringsFile = file("src/main/res/values/strings.xml")
        println("Final strings.xml content:")
        println(stringsFile.readText())

        val generatedStringsFile = file("build/intermediates/merged_res/release/values/values.xml")
        if (generatedStringsFile.exists()) {
            println("Generated values.xml content:")
            println(generatedStringsFile.readText())
        } else {
            println("Generated values.xml not found at expected location")
        }
    }
}

android.applicationVariants.all {
    val variant = this
    if (buildType.name == "release") {
        val assembleTask = tasks.named("assemble${variant.name.capitalize()}")
        assembleTask.configure {
            dependsOn(preAssembleRelease)
            finalizedBy(postAssembleRelease)
        }
    }
}

afterEvaluate {
    tasks.named("assembleRelease").configure {
        doLast {
            println("==== CHECKING APK CONTENTS ====")
            val apkFile = file("build/outputs/apk/release/app-release.apk")
            if (apkFile.exists()) {
                println("APK file found: ${apkFile.absolutePath}")
                // Здесь можно добавить дополнительные проверки содержимого APK
            } else {
                println("APK file not found at expected location")
            }
        }
    }
}
