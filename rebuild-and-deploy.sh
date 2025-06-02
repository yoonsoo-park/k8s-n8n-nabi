#!/bin/bash

# Exit on any error
set -e

echo "==== REBUILDING AND DEPLOYING N8N PLATFORM ===="

# Stop and remove containers to ensure clean state
echo "Stopping all services..."
docker-compose down

# Start services
echo "Starting all services..."
docker-compose up -d --scale n8n-worker=1

# Follow logs
echo "Following n8n logs..."
docker-compose logs -f n8n 