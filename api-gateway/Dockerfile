# Use JDK runtime only (pas Maven ici)
FROM eclipse-temurin:17-jdk

WORKDIR /app

# Copie du .jar compilé en dehors du conteneur
COPY target/*.jar app.jar

EXPOSE 8181

ENTRYPOINT ["java", "-jar", "app.jar"]
