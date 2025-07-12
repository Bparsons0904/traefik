#!/bin/bash

set -e  # Exit on any error

echo "🚀 Starting Traefik deployment on server..."

# Execute deployment commands via SSH
ssh server@192.168.86.203 << 'EOF'
set -e

echo "📍 Remote deployment starting..."

# Navigate to traefik directory
cd /home/server/traefik

# Pull latest changes
echo "📥 Pulling latest changes from git..."
git pull

# Ensure acme.json exists with correct permissions
if [ ! -f "acme.json" ]; then
    echo "📄 Creating acme.json..."
    touch acme.json
    chmod 600 acme.json
fi

# Load authentication setup from local script
if [ -f "./auth-setup.sh" ]; then
    echo "🔐 Loading authentication from local script..."
    source ./auth-setup.sh
else
    echo "❌ auth-setup.sh not found! Please create it locally."
    echo "   It should export TRAEFIK_AUTH_HASH with the admin credentials."
    exit 1
fi

# Ensure external network exists
echo "🌐 Ensuring traefik network exists..."
docker network create traefik 2>/dev/null || echo "Network already exists"

# Pull latest Traefik image
echo "⬇️  Pulling latest Traefik image..."
docker-compose pull

# Stop and remove existing container (if any)
echo "🛑 Stopping existing Traefik container..."
docker-compose down || true

# Start new container
echo "▶️  Starting Traefik..."
docker-compose up -d

# Wait a moment for startup
sleep 3

# Check status
echo "✅ Checking Traefik status..."
if docker-compose ps | grep -q "Up"; then
    echo "🎉 Traefik deployed successfully!"
    docker-compose ps
else
    echo "❌ Traefik failed to start. Checking logs..."
    docker-compose logs
    exit 1
fi

# Cleanup old images
echo "🧹 Cleaning up old images..."
docker image prune -f

echo "✨ Remote deployment complete!"
EOF

echo "🎯 Deployment script finished!"