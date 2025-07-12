# Traefik Hybrid Configuration Plan

## Overview
This document outlines how to extend the current Docker auto-discovery setup to support static file configuration for NAS services while maintaining the existing dynamic discovery.

## Current Setup (Dynamic Only)
- **Docker Provider**: Auto-discovers services with Traefik labels
- **Services**: bobparsons.dev, drone, traefik dashboard
- **Configuration**: Pure dynamic via Docker labels

## Future Hybrid Setup

### 1. Traefik Configuration (traefik.yml)
```yaml
providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: traefik
  file:
    filename: /config.yml
    watch: true  # Auto-reload when config.yml changes
```

### 2. Docker Compose Updates (docker-compose.yaml)
```yaml
volumes:
  - ./traefik.yml:/traefik.yml:ro
  - ./config.yml:/config.yml:ro  # Re-add static config mount
  - ./acme.json:/acme.json
  - /var/run/docker.sock:/var/run/docker.sock:ro
```

### 3. Static Configuration (config.yml)
```yaml
http:
  routers:
    # Example NAS service
    nas-plex:
      rule: "Host(`plex.bobparsons.dev`)"
      service: nas-plex-service
      entryPoints:
        - http
        - https
      tls:
        certResolver: letsencrypt
      middlewares:
        - nas-auth@file  # Reference middleware from file provider
    
    nas-jellyfin:
      rule: "Host(`jellyfin.bobparsons.dev`)"
      service: nas-jellyfin-service
      entryPoints:
        - http
        - https
      tls:
        certResolver: letsencrypt

  services:
    nas-plex-service:
      loadBalancer:
        servers:
          - url: "http://192.168.1.100:32400"  # NAS IP and Plex port
    
    nas-jellyfin-service:
      loadBalancer:
        servers:
          - url: "http://192.168.1.100:8096"   # NAS IP and Jellyfin port

  middlewares:
    # Shared authentication for NAS services
    nas-auth:
      basicAuth:
        users:
          - "${NAS_AUTH_HASH}"
    
    # Example rate limiting for NAS services
    nas-rate-limit:
      rateLimit:
        burst: 100
        average: 50
```

### 4. Environment Variables (.env.example)
```bash
# Existing Traefik variables
TRAEFIK_AUTH_HASH=username:$$2y$$10$$hashedpassword

# New NAS service variables
NAS_AUTH_HASH=nasuser:$$2y$$10$$anotherhash
NAS_IP=192.168.1.100
```

## Cross-Provider Features

### Referencing Resources Across Providers
- **File provider resource**: `my-middleware@file`
- **Docker provider resource**: `my-service@docker`

### Example: Docker Service Using File Middleware
```yaml
# In Docker container labels
labels:
  - "traefik.http.routers.my-app.middlewares=nas-auth@file,rate-limit@docker"
```

### Example: File Router Using Docker Service
```yaml
# In config.yml (if needed)
http:
  routers:
    external-to-docker:
      rule: "Host(`external.bobparsons.dev`)"
      service: "my-docker-service@docker"  # Reference Docker service
```

## Benefits of Hybrid Approach

### Docker Provider (Dynamic)
- ✅ Auto-discovery for containerized services
- ✅ No manual config changes needed
- ✅ Perfect for CI/CD deployments
- ✅ Services: bobparsons.dev, drone, etc.

### File Provider (Static)
- ✅ Traditional config for external services
- ✅ NAS services running on different hosts
- ✅ Complex routing rules
- ✅ Services: Plex, Jellyfin, NAS web interfaces

### Shared Resources
- ✅ SSL certificates work for both providers
- ✅ Middlewares can be shared across providers
- ✅ Single Traefik dashboard shows all services
- ✅ Unified logging and monitoring

## Implementation Steps (Future)

1. **Update traefik.yml** - Add file provider alongside Docker
2. **Update docker-compose.yaml** - Re-add config.yml volume mount
3. **Create proper config.yml** - Replace placeholder with NAS service configs
4. **Update environment variables** - Add NAS-specific variables
5. **Test hybrid setup** - Verify both dynamic and static services work
6. **Add NAS services incrementally** - One service at a time

## Notes
- Current dynamic-only setup should be tested first
- Hybrid implementation only when NAS services are actually needed
- Both providers can coexist without conflicts
- File provider changes are automatically reloaded (watch: true)