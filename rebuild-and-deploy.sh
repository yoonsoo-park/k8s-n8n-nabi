#!/bin/bash

# Exit on any error
set -e

echo "==== REBUILDING AND DEPLOYING MCP SERVER ===="

# Clean any existing dist directory to ensure a clean build
echo "Cleaning dist directory..."
cd mcp-server
rm -rf dist
mkdir -p dist/tools

# Build TypeScript files
echo "Building TypeScript..."
npm run build

# Check compiled tools - should only show .js files
echo "Checking compiled tools..."
ls -la dist/tools

# Move back to root directory
cd ..

# Stop and remove containers to ensure clean state
echo "Stopping all services..."
docker-compose down

# Remove existing images to force a complete rebuild
echo "Removing existing mcp-server image..."
docker rmi $(docker images -q "*mcp-server" 2>/dev/null) 2>/dev/null || true

# Force rebuild of Docker image
echo "Rebuilding Docker image..."
docker-compose build --no-cache mcp-server

# Start services
echo "Starting all services..."
docker-compose up -d --scale n8n-worker=1

# Follow logs
echo "Following MCP server logs..."
docker-compose logs -f mcp-server 