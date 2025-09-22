#!/bin/bash

DOCKER_USER="otniel217"
VERSION="latest"

# Liste des services
SERVICES=(
  "product-service"
  "order-service"
  "inventory-service"
  "discovery-server"
  "api-gateway"
  "notification-service"
)

for SERVICE in "${SERVICES[@]}"; do
  echo "🚀 Building Docker image for $SERVICE"

  # Chemin vers le dossier du service
  cd "$SERVICE" || { echo "❌ Failed to cd into $SERVICE"; exit 1; }

  # Check si target/*.jar existe
  JAR_FILE=$(find target -name "*.jar" | head -n 1)
  if [[ -z "$JAR_FILE" ]]; then
    echo "❌ No JAR found in $SERVICE/target. Run 'mvn clean install' first."
    cd ..
    continue
  fi

  # Build image
  docker build -t "$DOCKER_USER/$SERVICE:$VERSION" .

  # Push image
  docker push "$DOCKER_USER/$SERVICE:$VERSION"

  # Retour au dossier racine
  cd ..
done
