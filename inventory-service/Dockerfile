FROM alpine/openjdk:17-jre
WORKDIR /app
COPY target/inventory-service-0.0.1-SNAPSHOT.jar app.jar
EXPOSE 8082
ENTRYPOINT ["java", "-jar", "app.jar"]