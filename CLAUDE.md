# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Traefik reverse proxy setup configured for Docker auto-discovery with SSL/TLS termination using Let's Encrypt. The setup serves as a central gateway routing traffic to containerized services based on Docker labels.

## Architecture

### Core Components
- **Traefik Container**: Runs Traefik v2.10 as the main reverse proxy
- **Docker Provider**: Automatically discovers services with Traefik labels 
- **Let's Encrypt Integration**: Automatic SSL certificate generation via HTTP challenge
- **Basic Auth Dashboard**: Secured Traefik dashboard accessible at `traefik.bobparsons.dev`

### Network Configuration
- **External Network**: `traefik` network for inter-service communication
- **Port Mapping**: 
  - 80 (HTTP) → redirects to HTTPS
  - 443 (HTTPS) → main traffic
  - 8081 → Traefik dashboard (mapped from internal 8080)

### File Structure
- `traefik.yml`: Main Traefik configuration (static)
- `docker-compose.yaml`: Container orchestration and service labels
- `config.yml`: Currently unused (migrated to Docker auto-discovery)
- `acme.json`: Let's Encrypt certificate storage (auto-managed)
- `deploy.sh`: Remote deployment script via SSH

## Common Commands

### Local Development
```bash
# Start Traefik stack
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down

# Pull latest images
docker-compose pull

# Check container status
docker-compose ps
```

### Remote Deployment
```bash
# Deploy to production server (automated script)
./deploy.sh
```

### SSL Certificate Management
```bash
# Check certificate status
docker-compose exec traefik ls -la /acme.json

# Reset certificates (if needed)
docker-compose down
rm acme.json
touch acme.json
chmod 600 acme.json
docker-compose up -d
```

### Environment Setup
```bash
# Create environment file from template
cp .env.example .env

# Generate basic auth hash for dashboard
echo $(htpasswd -nb username password) | sed -e s/\\$/\\$\\$/g
```

## Service Discovery Pattern

Services are auto-discovered using Docker labels:
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.service-name.rule=Host(`domain.example.com`)"
  - "traefik.http.routers.service-name.entrypoints=http,https"
  - "traefik.http.routers.service-name.tls=true"
  - "traefik.http.routers.service-name.tls.certresolver=letsencrypt"
```

## Required Environment Variables

- `TRAEFIK_AUTH_HASH`: Basic auth credentials for dashboard access

## Deployment Architecture

The setup uses a hybrid approach:
- **Current**: Pure Docker auto-discovery for containerized services
- **Planned**: Hybrid configuration supporting static file config for external services (NAS, etc.)

## Important Files

- `traefik.yml:1-29`: Main static configuration with providers and entry points
- `docker-compose.yaml:17-24`: Dashboard routing and authentication setup  
- `deploy.sh:8-62`: Complete remote deployment workflow
- `traefik-hybrid-plan.md`: Detailed plan for adding static file configuration

## Security Notes

- Dashboard protected with basic authentication
- All HTTP traffic auto-redirects to HTTPS
- SSL certificates auto-renewed via Let's Encrypt
- Docker socket mounted read-only for security