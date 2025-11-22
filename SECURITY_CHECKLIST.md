# Plane Security Checklist & Best Practices

Complete security checklist for deploying and maintaining Plane in production.

## Table of Contents
1. [Pre-Deployment Security](#pre-deployment-security)
2. [Credentials & Secrets Management](#credentials--secrets-management)
3. [Network Security](#network-security)
4. [Application Security](#application-security)
5. [Data Security](#data-security)
6. [Monitoring & Auditing](#monitoring--auditing)
7. [Regular Maintenance](#regular-maintenance)

---

## Pre-Deployment Security

### ✅ **Before Going Live**

#### 1. **Change All Default Credentials**

- [ ] Django `SECRET_KEY` is randomly generated (50+ characters)
- [ ] PostgreSQL `POSTGRES_PASSWORD` is strong and unique
- [ ] RabbitMQ `RABBITMQ_PASSWORD` is strong and unique
- [ ] MinIO `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` are strong
- [ ] All passwords are stored securely (password manager)
- [ ] No default credentials remain (no "plane", "admin", "password")

**How to Generate Credentials:**
```bash
# Django SECRET_KEY (50+ characters)
python3 -c 'import secrets; print(secrets.token_urlsafe(50))'

# PostgreSQL Password (32+ characters)
openssl rand -base64 32

# RabbitMQ Password (32+ characters)
openssl rand -base64 32

# MinIO Access Key (self-hosted storage only, 27 characters)
openssl rand -base64 20 | tr -d '/+=' | head -c 27

# MinIO Secret Key (self-hosted storage only, 40+ characters)
openssl rand -base64 40
```

**Example Generated Credentials:**
```bash
# These are placeholders - GENERATE YOUR OWN using commands above!
SECRET_KEY=<your-generated-secret-key>
POSTGRES_PASSWORD=<your-generated-postgres-password>
RABBITMQ_PASSWORD=<your-generated-rabbitmq-password>
AWS_ACCESS_KEY_ID=<your-storage-access-key>  # From DO/AWS console or generated for MinIO
AWS_SECRET_ACCESS_KEY=<your-storage-secret-key>  # From DO/AWS console or generated for MinIO
```

**Note**: For Digital Ocean Spaces or AWS S3, generate access keys from your cloud provider console instead of using the MinIO generation commands.

#### 2. **Verify SSL/TLS Configuration**

- [ ] HTTPS is enabled for all public domains
- [ ] SSL certificates are valid (Let's Encrypt via Traefik)
- [ ] HTTP is redirected to HTTPS
- [ ] HSTS header is enabled
- [ ] SSL Labs test score is A or higher: https://www.ssllabs.com/ssltest/

**Test Command:**
```bash
# Check SSL certificate
curl -vI https://plane.mohdop.com 2>&1 | grep -i ssl

# Check HTTPS redirect
curl -I http://plane.mohdop.com
# Should return: 301 Moved Permanently → https://
```

#### 3. **Environment Variable Security**

- [ ] `.env` files are NOT committed to git
- [ ] `.env` files have restricted permissions: `chmod 600 .env*`
- [ ] Environment variables are set in Dokploy (not in docker-compose files)
- [ ] No sensitive data in log files

**Verify:**
```bash
# Check .gitignore includes .env files
grep -E "^\.env" .gitignore

# Check file permissions
ls -la .env*
# Should show: -rw------- (600)
```

---

## Credentials & Secrets Management

### ✅ **Secrets Best Practices**

#### 1. **Django SECRET_KEY**

- [ ] Length: 50+ characters
- [ ] Randomness: Generated using cryptographically secure method
- [ ] **CRITICAL**: Same value in `.env.api`, `.env.worker`, `.env.beat-worker`, `.env.live`
- [ ] Never exposed in logs or error messages
- [ ] Rotated annually (requires JWT re-authentication)

**How to Generate:**
```bash
python3 -c "import secrets; print(secrets.token_urlsafe(50))"
```

**Where It's Used:**
- `.env.api` - `SECRET_KEY`
- `.env.worker` - `SECRET_KEY`
- `.env.beat-worker` - `SECRET_KEY`
- `.env.live` - `LIVE_SERVER_SECRET_KEY` (MUST be identical!)

#### 2. **Database Credentials**

- [ ] Strong password (32+ characters, random)
- [ ] Not reused from other services
- [ ] Identical in `.env.infra`, `.env.api`, `.env.worker`, `.env.beat-worker`
- [ ] PostgreSQL accessible only within Docker network
- [ ] No public port exposure in production

**How to Generate:**
```bash
openssl rand -base64 32
```

**Where It's Used:**
- `.env.infra` - `POSTGRES_PASSWORD`
- `.env.api` - `POSTGRES_PASSWORD`
- `.env.worker` - `POSTGRES_PASSWORD`
- `.env.beat-worker` - `POSTGRES_PASSWORD`
- `.env.migrator` - `POSTGRES_PASSWORD`

#### 3. **OpenAI API Key**

- [ ] Valid API key from OpenAI dashboard
- [ ] Usage limits configured in OpenAI dashboard
- [ ] Monthly billing alerts set up
- [ ] Key has restricted permissions (if possible)
- [ ] Monitored for unusual usage

**Security:**
```bash
# In .env.api and .env.worker
OPENAI_API_KEY=sk-proj-xxxxxxxxxxxxxxxxxxxxx  # Never share!

# Set usage limits in OpenAI dashboard:
# https://platform.openai.com/settings/organization/limits
```

#### 4. **Email SMTP Credentials**

- [ ] Using app-specific password (not account password)
- [ ] Gmail: 2FA enabled + app password generated
- [ ] SendGrid/Mailgun: API key with minimal permissions
- [ ] From address is configured and verified
- [ ] Rate limits understood and configured

**Gmail App Password:**
1. Enable 2FA: https://myaccount.google.com/security
2. Generate app password: https://myaccount.google.com/apppasswords
3. Use app password in `EMAIL_HOST_PASSWORD`

---

## Network Security

### ✅ **Network Configuration**

#### 1. **Firewall Rules**

- [ ] Only ports 80 (HTTP) and 443 (HTTPS) are publicly exposed
- [ ] SSH port is changed from default 22 (optional but recommended)
- [ ] UFW or iptables configured:

```bash
# Configure UFW
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp   # SSH (change port if you modified it)
sudo ufw allow 80/tcp   # HTTP
sudo ufw allow 443/tcp  # HTTPS
sudo ufw enable
```

#### 2. **Docker Network Isolation**

- [ ] `plane-network` is a bridge network (not host)
- [ ] Infrastructure services NOT exposed to public internet
- [ ] Only API and Frontend have Traefik labels
- [ ] Inter-service communication uses internal DNS (container names)

**Verify:**
```bash
# Check network is bridge (not host)
docker network inspect plane-network | grep '"Driver"'
# Should show: "Driver": "bridge"

# Check exposed ports
docker ps --format "{{.Names}}\t{{.Ports}}"
# Infrastructure services should NOT have public port mappings
```

#### 3. **CORS Configuration**

- [ ] `CORS_ALLOWED_ORIGINS` is specific (not `*`)
- [ ] No trailing slashes in origins
- [ ] Only production domains listed
- [ ] Credentials are allowed (`CORS_ALLOW_CREDENTIALS = True`)

**Configuration:**
```bash
# In .env.api
CORS_ALLOWED_ORIGINS=https://plane.mohdop.com

# NOT this:
# CORS_ALLOWED_ORIGINS=*  ❌ NEVER USE IN PRODUCTION!
```

---

## Application Security

### ✅ **Django Security Settings**

#### 1. **Debug Mode**

- [ ] `DEBUG=0` in all production `.env` files
- [ ] No debug information exposed in error pages
- [ ] Custom error pages configured (404, 500)

**Verify:**
```bash
# Check all .env files
grep DEBUG .env.*

# Should show: DEBUG=0 (or not set)
# NEVER: DEBUG=1 in production!
```

#### 2. **Secure Cookies**

- [ ] `SESSION_COOKIE_SECURE=1` (HTTPS only)
- [ ] `CSRF_COOKIE_SECURE=1` (HTTPS only)
- [ ] `SESSION_COOKIE_HTTPONLY=1` (prevent JavaScript access)
- [ ] `CSRF_COOKIE_HTTPONLY=1`

**Configuration:**
```bash
# In .env.api
SESSION_COOKIE_SECURE=1
CSRF_COOKIE_SECURE=1
```

#### 3. **Allowed Hosts**

- [ ] `ALLOWED_HOSTS` contains only production domains
- [ ] No wildcards in production

**Configuration:**
```bash
# In .env.api
ALLOWED_HOSTS=plane-api.mohdop.com,localhost

# For multiple domains:
ALLOWED_HOSTS=plane-api.mohdop.com,api.example.com,localhost
```

#### 4. **Rate Limiting**

- [ ] API rate limiting enabled
- [ ] Nginx rate limiting configured
- [ ] Login endpoint has strict rate limiting
- [ ] Brute force protection in place

**Configuration:**
```bash
# In .env.api
API_KEY_RATE_LIMIT=60/minute

# In nginx/combined-frontend.conf
limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;
```

---

## Data Security

### ✅ **Data Protection**

#### 1. **Database Encryption**

- [ ] PostgreSQL connections use SSL (optional, for external connections)
- [ ] Data at rest encryption enabled (disk encryption)
- [ ] Regular backups configured
- [ ] Backups are encrypted

**Backup Script:**
```bash
#!/bin/bash
# Daily database backup (encrypted)

BACKUP_DIR="/backups/plane"
DATE=$(date +%Y%m%d_%H%M%S)
GPG_KEY="your-gpg-key-id"

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup database
docker exec plane-postgres pg_dump -U plane plane | \
  gzip | \
  gpg --encrypt --recipient $GPG_KEY > \
  $BACKUP_DIR/plane_db_$DATE.sql.gz.gpg

# Retain last 30 days
find $BACKUP_DIR -type f -mtime +30 -delete
```

#### 2. **File Storage Security**

- [ ] MinIO bucket is NOT publicly accessible (unless required)
- [ ] Signed URLs used for file downloads
- [ ] File upload size limits configured
- [ ] File type validation in place

**MinIO Security:**
```bash
# Check bucket policy
docker exec plane-minio mc policy get minio/uploads

# For production, use 'none' or 'download' (not 'public')
# To change:
docker exec plane-minio mc policy set download minio/uploads
```

**File Upload Limits:**
```bash
# In .env.api
FILE_SIZE_LIMIT=5242880  # 5MB in bytes

# In nginx/combined-frontend.conf
client_max_body_size 50M;
```

#### 3. **Sensitive Data Handling**

- [ ] PII (Personally Identifiable Information) is encrypted
- [ ] Passwords are hashed (Django does this by default)
- [ ] API tokens are hashed
- [ ] Audit logs for data access

---

## Monitoring & Auditing

### ✅ **Security Monitoring**

#### 1. **Log Management**

- [ ] All services logging enabled
- [ ] Logs rotated to prevent disk full
- [ ] No sensitive data in logs (passwords, tokens)
- [ ] Failed login attempts logged

**Log Rotation:**
```bash
# Docker logs configuration
# /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

#### 2. **Security Headers**

- [ ] X-Frame-Options: SAMEORIGIN
- [ ] X-Content-Type-Options: nosniff
- [ ] X-XSS-Protection: 1; mode=block
- [ ] Referrer-Policy: strict-origin-when-cross-origin
- [ ] Content-Security-Policy (CSP) configured

**Test Headers:**
```bash
curl -I https://plane.mohdop.com/ | grep -E "X-|Content-Security"
```

#### 3. **Intrusion Detection**

- [ ] Fail2ban configured for SSH
- [ ] Unusual login patterns monitored
- [ ] Automated alerts for security events
- [ ] Regular security scans

**Fail2ban for SSH:**
```bash
sudo apt install fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

---

## Regular Maintenance

### ✅ **Security Maintenance Schedule**

#### Daily

- [ ] Review error logs for anomalies
- [ ] Check disk space and resource usage
- [ ] Verify all services are running

```bash
# Daily check script
docker ps | grep plane
df -h
docker stats --no-stream
```

#### Weekly

- [ ] Review access logs for suspicious activity
- [ ] Check for failed login attempts
- [ ] Verify backups are running successfully
- [ ] Test backup restoration

```bash
# Weekly backup test
# Restore latest backup to test database
```

#### Monthly

- [ ] Update Docker images
- [ ] Update OS packages
- [ ] Review and rotate API keys (if needed)
- [ ] Security scan with tools like:
  - OWASP ZAP
  - Nmap
  - Nikto

```bash
# Update OS packages
sudo apt update && sudo apt upgrade -y

# Update Docker images
docker-compose pull
docker-compose up -d
```

#### Annually

- [ ] Rotate Django SECRET_KEY (requires re-authentication)
- [ ] Review and update SSL certificates (Let's Encrypt auto-renews)
- [ ] Security audit by third party (recommended)
- [ ] Disaster recovery test

---

## Incident Response

### ✅ **If Security Breach Occurs**

#### Immediate Actions

1. **Isolate affected systems**
   ```bash
   docker-compose down  # Stop all services
   ```

2. **Preserve evidence**
   ```bash
   # Copy all logs
   docker logs plane-api > /tmp/api-logs.txt
   docker logs plane-postgres > /tmp/db-logs.txt
   ```

3. **Assess damage**
   - Check database for unauthorized changes
   - Review access logs
   - Identify compromised accounts

4. **Notify stakeholders**
   - Inform users if data breach occurred
   - Contact authorities if required (GDPR, etc.)

5. **Remediate**
   - Change all passwords
   - Rotate SECRET_KEY
   - Patch vulnerabilities
   - Restore from backup if needed

6. **Post-incident review**
   - Document what happened
   - Identify root cause
   - Implement preventive measures

---

## Security Tools & Resources

### Recommended Tools

1. **Security Scanning**
   - **OWASP ZAP**: https://www.zaproxy.org/
   - **Nmap**: Port scanning
   - **Nikto**: Web server scanner

2. **Monitoring**
   - **Sentry**: Error tracking
   - **Prometheus + Grafana**: Metrics
   - **ELK Stack**: Log aggregation

3. **Backup**
   - **Restic**: Encrypted backups
   - **BorgBackup**: Deduplicated backups
   - **rsync**: Simple file backups

### Security Checklists

- [ ] OWASP Top 10: https://owasp.org/www-project-top-ten/
- [ ] CIS Docker Benchmark: https://www.cisecurity.org/benchmark/docker
- [ ] Django Security Checklist: https://docs.djangoproject.com/en/stable/howto/deployment/checklist/

---

## Quick Security Audit

Run this script to perform a quick security check:

```bash
#!/bin/bash
# quick-security-audit.sh

echo "=== Plane Security Audit ==="
echo

echo "1. Checking DEBUG mode..."
docker exec plane-api python -c "from django.conf import settings; print('DEBUG:', settings.DEBUG)"

echo
echo "2. Checking SECRET_KEY..."
docker exec plane-api python -c "from django.conf import settings; print('Length:', len(settings.SECRET_KEY))"

echo
echo "3. Checking ALLOWED_HOSTS..."
docker exec plane-api python -c "from django.conf import settings; print('Hosts:', settings.ALLOWED_HOSTS)"

echo
echo "4. Checking SSL certificates..."
curl -vI https://plane.mohdop.com 2>&1 | grep -i "expire"

echo
echo "5. Checking exposed ports..."
docker ps --format "{{.Names}}\t{{.Ports}}" | grep plane

echo
echo "6. Checking disk space..."
df -h | grep -E '/$|/var'

echo
echo "7. Checking service status..."
docker ps --filter "name=plane" --format "{{.Names}}\t{{.Status}}"

echo
echo "=== Audit Complete ==="
```

---

## Summary

### Critical Security Checklist

- [ ] **All default passwords changed**
- [ ] **DEBUG=0 in production**
- [ ] **HTTPS enabled (valid SSL certificates)**
- [ ] **SECRET_KEY is strong and consistent across services**
- [ ] **CORS_ALLOWED_ORIGINS is specific (not `*`)**
- [ ] **Secure cookies enabled**
- [ ] **Firewall configured (only 80/443 exposed)**
- [ ] **Database not publicly accessible**
- [ ] **Backups automated and tested**
- [ ] **Logs reviewed regularly**
- [ ] **Security updates applied monthly**
- [ ] **Incident response plan documented**

### Priority Levels

**🔴 Critical** (Do immediately):
- Change default passwords
- Enable HTTPS
- Set DEBUG=0
- Configure firewall

**🟡 Important** (Do within 1 week):
- Set up automated backups
- Configure rate limiting
- Enable security headers
- Set up monitoring

**🟢 Recommended** (Do within 1 month):
- Security scanning
- Log aggregation
- Intrusion detection
- Third-party audit

---

**Remember**: Security is an ongoing process, not a one-time task. Regularly review and update your security posture!
