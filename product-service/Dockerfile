# syntax=docker/dockerfile:1
FROM eclipse-temurin:17-jdk

WORKDIR /app

# Copie du JAR compilé (déjà généré en local avec mvn clean install)
COPY target/*.jar app.jar

# Port exposé (⚠️ adapte si nécessaire)
EXPOSE 8081

ENTRYPOINT ["java", "-jar", "app.jar"]
