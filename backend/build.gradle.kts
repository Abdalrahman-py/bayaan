
plugins {
    alias(libs.plugins.kotlin.jvm)
    alias(ktorLibs.plugins.ktor)
}

group = "com.bayaan"
version = "1.0.0-SNAPSHOT"

application {
    mainClass = "io.ktor.server.netty.EngineMain"
}

kotlin {
    jvmToolchain(21)
}
dependencies {
    implementation(ktorLibs.server.config.yaml)
    implementation(ktorLibs.server.core)
    implementation(ktorLibs.server.netty)
    implementation(libs.logback.classic)

    // HTTP client to forward audio to the quran-muaalem engine on Modal.
    implementation(ktorLibs.client.core)
    implementation(ktorLibs.client.cio)

    testImplementation(kotlin("test"))
    testImplementation(ktorLibs.server.testHost)
}
