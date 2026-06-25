FROM eclipse-temurin:21-jdk AS build
WORKDIR /app
COPY . .
RUN ./gradlew buildFatJar --no-daemon -x test

FROM eclipse-temurin:21-jre
# ffmpeg: the app shells out to it (see Routing.kt convertToWav) to turn the
# phone's recording into the 16kHz mono WAV the muaalem engine expects.
RUN apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /app/build/libs/bayaan-all.jar app.jar
CMD ["java", "-jar", "app.jar"]
