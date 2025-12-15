# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Traefik reverse proxy setup configured for Docker auto-discovery with SSL/TLS termination using Let's Encrypt. The setup serves as a central gateway routing traffic to containerized services based on Docker labels.

## Architecture

### Core Components
- **Traefik Container**: Runs Traefik v3.6.2 as the main reverse proxy
- **Docker Provider**: Automatically discovers services with Traefik labels
- **Let's Encrypt Integration**: Automatic SSL certificate generation via HTTP challenge
- **Basic Auth Dashboard**: Secured Traefik dashboard accessible at `traefik.bobparsons.dev`
- **Security Middlewares**: Built-in rate limiting, security headers, and compression
- **Access Logging**: JSON-formatted logs for monitoring and security analysis
- **Metrics**: Prometheus metrics for monitoring and observability

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
- `logs/`: Directory containing Traefik access logs in JSON format
- `logrotate.conf`: Log rotation configuration to prevent disk space issues

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

Services are auto-discovered using Docker labels. Apply security middlewares to protect your services:

### Basic Service (recommended for most services)
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.service-name.rule=Host(`domain.example.com`)"
  - "traefik.http.routers.service-name.entrypoints=http,https"
  - "traefik.http.routers.service-name.tls=true"
  - "traefik.http.routers.service-name.tls.certresolver=letsencrypt"
  # Apply security middlewares
  - "traefik.http.routers.service-name.middlewares=rate-limit@file,security-headers@file,compress@file"
```

### Sensitive Service (stricter rate limiting)
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.service-name.rule=Host(`domain.example.com`)"
  - "traefik.http.routers.service-name.entrypoints=http,https"
  - "traefik.http.routers.service-name.tls=true"
  - "traefik.http.routers.service-name.tls.certresolver=letsencrypt"
  # Use stricter rate limiting for auth endpoints, admin panels, etc.
  - "traefik.http.routers.service-name.middlewares=rate-limit-strict@file,security-headers@file,compress@file"
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

## Security & Observability

### Built-in Security Middlewares
The setup includes three core middlewares configured in `traefik.yml:44-78`:

1. **Rate Limiting** (`rate-limit` and `rate-limit-strict`)
   - Standard: 100 req/s average, 50 burst
   - Strict: 10 req/s average, 5 burst (for sensitive endpoints)
   - Prevents DoS attacks and API abuse

2. **Security Headers** (`security-headers`)
   - HSTS with preload (31536000 seconds)
   - XSS protection and content-type sniffing prevention
   - Frame options set to SAMEORIGIN
   - Removes server header to hide version info

3. **Compression** (`compress`)
   - Automatic Gzip/Brotli compression
   - Reduces bandwidth and improves performance

### Access Logging
- **Format**: JSON for easy parsing and analysis
- **Location**: `./logs/access.log`
- **Rotation**: Configured via `logrotate.conf` (14 days retention)
- **Usage**: Monitor traffic patterns, debug issues, feed to Fail2ban

### Log Management
```bash
# View recent access logs
tail -f logs/access.log | jq

# Search for specific status codes
jq 'select(.DownstreamStatus == 404)' logs/access.log

# Count requests by client IP
jq -r '.ClientAddr' logs/access.log | sort | uniq -c | sort -rn

# Setup log rotation (run as root)
sudo ln -s $(pwd)/logrotate.conf /etc/logrotate.d/traefik
sudo logrotate -f /etc/logrotate.d/traefik
```

### Fail2ban Integration (Optional)
To add IP-based blocking for repeat offenders, you can configure Fail2ban to parse the JSON access logs:

1. Create a filter in `/etc/fail2ban/filter.d/traefik-auth.conf`:
```ini
[Definition]
failregex = ^.*"ClientAddr":"<HOST>:\d+".*"DownstreamStatus":401.*$
ignoreregex =
```

2. Add jail in `/etc/fail2ban/jail.local`:
```ini
[traefik-auth]
enabled = true
port = http,https
filter = traefik-auth
logpath = /home/server/traefik/logs/access.log
maxretry = 5
bantime = 3600
findtime = 600
```

### Security Checklist
- [x] Dashboard protected with basic authentication
- [x] All HTTP traffic auto-redirects to HTTPS
- [x] SSL certificates auto-renewed via Let's Encrypt
- [x] Docker socket mounted read-only for security
- [x] Rate limiting enabled to prevent abuse
- [x] Security headers configured (HSTS, XSS protection, etc.)
- [x] Access logs enabled for monitoring and auditing
- [x] Compression enabled to reduce bandwidth
- [x] Prometheus metrics exposed for monitoring