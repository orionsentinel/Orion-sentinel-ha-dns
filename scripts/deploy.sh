#!/bin/bash

# Deploy all stacks

echo "Starting deployment of all stacks..."

docker-compose -f stacks/dns/docker-compose.yml up -d
docker-compose -f stacks/observability/docker-compose.yml up -d
docker-compose -f stacks/ai-watchdog/docker-compose.yml up -d

# Show status of all containers
echo "Showing status of all containers..."
docker ps