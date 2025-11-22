# Digital Ocean Spaces Configuration Summary

**Status**: ✅ Configured (MinIO disabled)

---

## 📋 What Was Changed

Switched from self-hosted MinIO to Digital Ocean Spaces (S3-compatible).

### Files Updated (6 Total)

```
✅ deployment/6-services/.env.api
✅ deployment/6-services/.env.worker
✅ deployment/consolidated/.env.backend
✅ .env.api (root)
✅ .env.worker (root)
```

---

## 🔧 Your Configuration (Placeholders)

```bash
USE_MINIO=0
AWS_REGION=nyc3
AWS_S3_ENDPOINT_URL=https://nyc3.digitaloceanspaces.com
AWS_ACCESS_KEY_ID=your-do-spaces-access-key
AWS_SECRET_ACCESS_KEY=your-do-spaces-secret-key
AWS_S3_BUCKET_NAME=your-space-name
```

---

## ⚠️ ACTION REQUIRED: Add Your DO Spaces Credentials

### Step 1: Get Your Credentials

1. Go to **DigitalOcean Console** → **API** → **Spaces Keys**
2. Click **"Generate New Key"**
3. Copy:
   - **Access Key** (starts with `DO...`)
   - **Secret Key** (shown only once!)

### Step 2: Update Environment Files

Replace placeholders in these files:

**For 6-services deployment:**
```bash
# Edit deployment/6-services/.env.api
# Edit deployment/6-services/.env.worker

AWS_ACCESS_KEY_ID=DO00XXXXXXXXXXXXXXXXXX
AWS_SECRET_ACCESS_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
AWS_S3_BUCKET_NAME=plane-uploads    # Your Space name
AWS_REGION=nyc3                      # Your Space region
AWS_S3_ENDPOINT_URL=https://nyc3.digitaloceanspaces.com
```

**For consolidated deployment:**
```bash
# Edit deployment/consolidated/.env.backend
# (same values as above)
```

### Step 3: Choose Your Region

| Region Code | Location |
|-------------|----------|
| `nyc3` | New York |
| `sfo3` | San Francisco |
| `ams3` | Amsterdam |
| `sgp1` | Singapore |
| `fra1` | Frankfurt |

**Endpoint URL format**: `https://<region>.digitaloceanspaces.com`

---

## 🗑️ Remove MinIO from Infrastructure

Since you're using DO Spaces, you **don't need MinIO**.

### Option A: Comment Out MinIO (Recommended)

Edit `deployment/6-services/docker-compose.infra.yml`:

1. Comment out the entire `minio:` service section (lines ~96-136)
2. Comment out the `minio-setup:` service section (lines ~141-156)
3. Comment out `minio_data:` from volumes section

### Option B: Just Don't Start MinIO

When deploying to Dokploy, simply don't include MinIO in your deployment. The other services (postgres, redis, rabbitmq) will work fine without it.

### Option C: Keep MinIO as Backup

You can keep MinIO in the compose file but not use it. Just ensure:
- `USE_MINIO=0` in all .env files
- `AWS_S3_ENDPOINT_URL` points to DO Spaces

---

## ✅ Infrastructure Without MinIO

Your new infrastructure only needs:

```yaml
services:
  postgres:     # ✅ Keep - Database
  redis:        # ✅ Keep - Cache
  rabbitmq:     # ✅ Keep - Message queue
  # minio:      # ❌ Remove - Using DO Spaces instead
  # minio-setup: # ❌ Remove
```

---

## 🪣 Create Your Space (Bucket)

### Via DO Console:

1. Go to **Spaces** in DigitalOcean
2. Click **"Create a Space"**
3. Choose your region (e.g., nyc3)
4. Name your Space (e.g., `plane-uploads`)
5. Choose **"Restrict File Listing"** (recommended for security)
6. Create!

### Via doctl CLI:

```bash
doctl spaces create plane-uploads --region nyc3
```

---

## 🔒 CORS Configuration for DO Spaces

Your Space needs CORS configured to allow uploads from your frontend.

### Via DO Console:

1. Go to your Space → **Settings** → **CORS Configuration**
2. Add this configuration:

```json
[
  {
    "AllowedOrigins": ["https://plane.mohdop.com"],
    "AllowedMethods": ["GET", "PUT", "POST", "DELETE", "HEAD"],
    "AllowedHeaders": ["*"],
    "MaxAgeSeconds": 3000
  }
]
```

### Via s3cmd:

```bash
# Create cors.xml
cat > cors.xml << 'EOF'
<CORSConfiguration>
  <CORSRule>
    <AllowedOrigin>https://plane.mohdop.com</AllowedOrigin>
    <AllowedMethod>GET</AllowedMethod>
    <AllowedMethod>PUT</AllowedMethod>
    <AllowedMethod>POST</AllowedMethod>
    <AllowedMethod>DELETE</AllowedMethod>
    <AllowedMethod>HEAD</AllowedMethod>
    <AllowedHeader>*</AllowedHeader>
    <MaxAgeSeconds>3000</MaxAgeSeconds>
  </CORSRule>
</CORSConfiguration>
EOF

# Apply CORS
s3cmd setcors cors.xml s3://plane-uploads
```

---

## 📊 Configuration Comparison

| Setting | MinIO (Old) | DO Spaces (New) |
|---------|-------------|-----------------|
| `USE_MINIO` | `1` | `0` |
| `AWS_S3_ENDPOINT_URL` | `http://plane-minio:9000` | `https://nyc3.digitaloceanspaces.com` |
| `AWS_REGION` | `us-east-1` | `nyc3` (or your region) |
| `AWS_ACCESS_KEY_ID` | MinIO key | DO Spaces key |
| `AWS_SECRET_ACCESS_KEY` | MinIO secret | DO Spaces secret |
| SSL/HTTPS | No (internal) | Yes (required) |

---

## 🧪 Test Your Configuration

After deployment, test file upload:

```bash
# Connect to API container
docker exec -it plane-api python manage.py shell

# Test S3 connection
from django.core.files.storage import default_storage
from django.core.files.base import ContentFile

# Create test file
path = default_storage.save('test.txt', ContentFile('Hello from Plane!'))
print(f"File saved to: {path}")

# Verify it exists
print(f"File exists: {default_storage.exists(path)}")

# Get URL
print(f"File URL: {default_storage.url(path)}")

# Clean up
default_storage.delete(path)
```

---

## 🚨 Troubleshooting

### Error: "Access Denied"

**Causes:**
1. Wrong credentials
2. Space doesn't exist
3. Missing permissions

**Solutions:**
1. Verify Access Key and Secret Key
2. Create the Space in DO Console
3. Regenerate Spaces API key

### Error: "Endpoint URL Not Reachable"

**Causes:**
1. Wrong region in endpoint URL
2. Typo in URL

**Solutions:**
1. Verify region matches your Space
2. URL format: `https://<region>.digitaloceanspaces.com`

### Error: "CORS Error on Upload"

**Causes:**
1. CORS not configured on Space
2. Wrong origin in CORS config

**Solutions:**
1. Configure CORS (see above)
2. Use `https://plane.mohdop.com` as allowed origin

### Error: "SSL Certificate Error"

**Causes:**
1. Using `http://` instead of `https://`

**Solutions:**
1. Always use `https://` for DO Spaces endpoint

---

## ✅ Pre-Deployment Checklist

- [ ] DO Spaces Access Key obtained
- [ ] DO Spaces Secret Key obtained
- [ ] Space (bucket) created in DO Console
- [ ] CORS configured on Space
- [ ] All .env files updated with credentials
- [ ] MinIO removed/commented from docker-compose.infra.yml
- [ ] `USE_MINIO=0` in all environment files

---

## 📁 Files to Update with Your Credentials

### Required Updates:

| File | Variable | Your Value |
|------|----------|------------|
| `deployment/6-services/.env.api` | `AWS_ACCESS_KEY_ID` | `DO00XXX...` |
| | `AWS_SECRET_ACCESS_KEY` | Your secret |
| | `AWS_S3_BUCKET_NAME` | Your Space name |
| | `AWS_REGION` | Your region (e.g., nyc3) |
| `deployment/6-services/.env.worker` | (same as above) | |
| `deployment/consolidated/.env.backend` | (same as above) | |

---

## 🎉 Summary

| Item | Status |
|------|--------|
| MinIO disabled | ✅ `USE_MINIO=0` |
| DO Spaces endpoint configured | ✅ |
| Environment files updated | ✅ 6 files |
| Credentials | ⚠️ Add your DO Spaces keys |
| Space (bucket) | ⚠️ Create in DO Console |
| CORS | ⚠️ Configure on Space |
| MinIO in docker-compose | ⚠️ Remove or comment out |

**Ready to deploy once you add your DO Spaces credentials!**
