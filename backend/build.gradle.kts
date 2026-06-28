
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

    // Auth + JWT (Supabase HS256)
    implementation("io.ktor:ktor-server-auth-jvm")
    implementation("io.ktor:ktor-server-auth-jwt-jvm")

    // HTTP client to forward audio to the quran-muaalem engine on Modal.
    implementation(ktorLibs.client.core)
    implementation(ktorLibs.client.cio)

    // JSON parsing for engine response
    implementation("io.ktor:ktor-serialization-kotlinx-json-jvm")

    // Database: Supabase Postgres via Exposed + HikariCP
    implementation("org.jetbrains.exposed:exposed-core:0.61.0")
    implementation("org.jetbrains.exposed:exposed-jdbc:0.61.0")
    implementation("org.jetbrains.exposed:exposed-kotlin-datetime:0.61.0")
    implementation("org.postgresql:postgresql:42.7.4")
    implementation("com.zaxxer:HikariCP:6.2.1")
    implementation("org.jetbrains.kotlinx:kotlinx-datetime:0.6.1")

    testImplementation(kotlin("test"))
    testImplementation(ktorLibs.server.testHost)
}

tasks.withType<Test> {
    environment("SUPABASE_JWT_SECRET", "test-secret-for-bayaan-junit-testing-only-xx")
    environment("SUPABASE_PROJECT_REF", "test-project")
}
