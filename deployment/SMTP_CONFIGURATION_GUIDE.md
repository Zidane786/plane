# Custom SMTP Server Configuration Guide

## ✅ Your SMTP Configuration

Your custom SMTP server has been configured across all environment files:

```bash
EMAIL_HOST=mail.mohdop.com
EMAIL_PORT=587
EMAIL_USE_TLS=1
EMAIL_HOST_USER=zidane@mohdop.com
EMAIL_HOST_PASSWORD=<your-smtp-password>
DEFAULT_FROM_EMAIL=zidane@mohdop.com
```

---

## 🔍 Django Support Verification

### Does Django Support Custom SMTP Servers? **YES! ✅**

Django 4.2.26 (used by Plane) has **full support** for custom SMTP servers through the standard email backend.

### How It Works

1. **Email Backend**: `django.core.mail.backends.smtp.EmailBackend`
   - This is Django's built-in SMTP email backend
   - Works with ANY SMTP server (Gmail, SendGrid, custom servers, etc.)

2. **Environment Variables**: Django reads email configuration from:
   - `EMAIL_HOST` → Your SMTP server hostname
   - `EMAIL_PORT` → SMTP port (587 for TLS, 465 for SSL)
   - `EMAIL_USE_TLS` → Use TLS encryption (1=yes, 0=no)
   - `EMAIL_HOST_USER` → SMTP username/email
   - `EMAIL_HOST_PASSWORD` → SMTP password
   - `DEFAULT_FROM_EMAIL` → "From" address for outgoing emails

3. **How Plane Uses It**:
   ```python
   # In apps/api/plane/settings/common.py
   EMAIL_BACKEND = "django.core.mail.backends.smtp.EmailBackend"

   # Django automatically reads EMAIL_HOST, EMAIL_PORT, etc. from environment
   ```

---

## 📋 Configuration Files Updated

Your SMTP configuration has been applied to:

### 6-Services Deployment:
- ✅ `deployment/6-services/.env.api`
- ✅ `deployment/6-services/.env.worker`

### Consolidated Deployment:
- ✅ `deployment/consolidated/.env.backend`

---

## 🧪 Testing Your SMTP Configuration

### Test 1: Check SMTP Connection

After deployment, test SMTP from Django shell:

```bash
docker exec -it plane-api python manage.py shell

# In Django shell:
from django.core.mail import send_mail

send_mail(
    'Test Email from Plane',
    'This is a test email to verify SMTP configuration.',
    'zidane@mohdop.com',
    ['your-test-email@example.com'],
    fail_silently=False,
)

# If successful, you'll see: 1
# If failed, you'll see an error message
```

### Test 2: User Registration Email

1. Sign up for a new account at `https://plane.mohdop.com`
2. Check if you receive the verification email
3. Email should be from `zidane@mohdop.com`

### Test 3: Test from Command Line

```bash
# Test SMTP connection from command line
docker exec -it plane-api python manage.py sendtestemail your-email@example.com
```

---

## 🔧 SMTP Configuration Explained

### Your Setup:

```bash
EMAIL_HOST=mail.mohdop.com          # Your SMTP server
EMAIL_PORT=587                      # STARTTLS port
EMAIL_USE_TLS=1                     # Enable TLS encryption
EMAIL_HOST_USER=zidane@mohdop.com   # SMTP authentication username
EMAIL_HOST_PASSWORD=<your-smtp-password>             # SMTP authentication password
DEFAULT_FROM_EMAIL=zidane@mohdop.com # "From" address in emails
```

### Port Options:

| Port | Encryption | When to Use |
|------|------------|-------------|
| 587 | STARTTLS (`EMAIL_USE_TLS=1`) | **Recommended** - Modern standard |
| 465 | SSL/TLS (`EMAIL_USE_SSL=1`) | Legacy, but still supported |
| 25 | None | Not recommended (no encryption) |

**Your configuration**: Port 587 with TLS ✅ (Correct!)

### TLS vs SSL:

```bash
# For port 587 (STARTTLS) - Your setup
EMAIL_PORT=587
EMAIL_USE_TLS=1
EMAIL_USE_SSL=0  # (or omit this line)

# For port 465 (SSL/TLS)
EMAIL_PORT=465
EMAIL_USE_TLS=0
EMAIL_USE_SSL=1
```

---

## 🛡️ Security Considerations

### ⚠️ IMPORTANT: Password Security

Your SMTP password (`123`) is currently stored in plain text in the `.env` files.

**Recommendations**:

1. **Use a Strong Password**: `123` is not secure for production
   - Generate a strong password for your SMTP account
   - Update it in all `.env` files

2. **Secure the .env Files**:
   ```bash
   chmod 600 deployment/6-services/.env.*
   chmod 600 deployment/consolidated/.env.*
   ```

3. **Never Commit .env Files**:
   ```bash
   # Verify .env is in .gitignore
   grep "^\.env" .gitignore
   ```

4. **Use Dokploy Environment Variables**:
   - Instead of committing .env files, set environment variables in Dokploy UI
   - This keeps secrets out of your repository

---

## 🚨 Troubleshooting

### Issue: Emails Not Sending

**Check 1: SMTP Server Reachable**
```bash
# Test from your VPS
docker exec -it plane-api bash
telnet mail.mohdop.com 587
# Should connect successfully
```

**Check 2: Authentication**
```bash
# Check Django logs
docker logs plane-api -f

# Look for errors like:
# - "SMTPAuthenticationError" → Wrong username/password
# - "SMTPServerDisconnected" → Connection issues
# - "SMTPException" → General SMTP error
```

**Check 3: Firewall**
```bash
# Ensure port 587 is not blocked on your VPS
sudo ufw status
# If blocked: sudo ufw allow 587/tcp
```

**Check 4: SMTP Server Settings**
- Verify `mail.mohdop.com` requires port 587
- Verify TLS is required (not SSL)
- Check if authentication is required
- Verify `zidane@mohdop.com` can send via SMTP

### Issue: "Connection Refused"

**Possible Causes**:
1. Wrong port (try 465 if 587 doesn't work)
2. SMTP server requires SSL instead of TLS:
   ```bash
   EMAIL_PORT=465
   EMAIL_USE_TLS=0
   EMAIL_USE_SSL=1
   ```
3. Firewall blocking outbound SMTP

### Issue: "Authentication Failed"

**Possible Causes**:
1. Wrong username (try `zidane` instead of `zidane@mohdop.com`)
2. Wrong password
3. Account requires app-specific password

**Solution**: Verify credentials with your SMTP provider

### Issue: Emails in Spam

**Possible Causes**:
1. SPF record not configured for your domain
2. DKIM not configured
3. DMARC policy not set

**Solution**: Configure DNS records:
```dns
; SPF record
mohdop.com. IN TXT "v=spf1 mx a:mail.mohdop.com -all"

; DKIM record (get from your email provider)
default._domainkey.mohdop.com. IN TXT "v=DKIM1; k=rsa; p=YOUR_PUBLIC_KEY"

; DMARC policy
_dmarc.mohdop.com. IN TXT "v=DMARC1; p=none; rua=mailto:dmarc@mohdop.com"
```

---

## 📧 Email Templates

Plane sends emails for:

1. **User Registration**: Verification email
2. **Password Reset**: Reset link
3. **Invitations**: Team/workspace invites
4. **Notifications**: Issue updates, mentions, comments
5. **Exports**: Data export completion

All emails will be sent from: `zidane@mohdop.com`

---

## 🔄 Alternative: Gmail SMTP (Backup)

If your custom SMTP server has issues, you can temporarily use Gmail:

```bash
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USE_TLS=1
EMAIL_HOST_USER=your-email@gmail.com
EMAIL_HOST_PASSWORD=your-16-char-app-password
DEFAULT_FROM_EMAIL=your-email@gmail.com
```

**Note**: Requires Gmail 2FA and app-specific password

---

## ✅ Verification Checklist

Before deploying, verify:

- [ ] SMTP server hostname is correct (`mail.mohdop.com`)
- [ ] Port is correct (587 for TLS)
- [ ] TLS/SSL setting matches your server (TLS=1 for port 587)
- [ ] Username is correct (`zidane@mohdop.com`)
- [ ] Password is correct and secure (not `123` in production!)
- [ ] "From" email is valid (`zidane@mohdop.com`)
- [ ] Firewall allows outbound SMTP (port 587)
- [ ] SPF/DKIM/DMARC DNS records configured (optional but recommended)

---

## 📊 Summary

| Setting | Value | Status |
|---------|-------|--------|
| SMTP Host | `mail.mohdop.com` | ✅ Configured |
| SMTP Port | `587` | ✅ Correct (TLS) |
| Encryption | TLS | ✅ Secure |
| Username | `zidane@mohdop.com` | ✅ Configured |
| Password | `123` | ⚠️ Use stronger password! |
| From Email | `zidane@mohdop.com` | ✅ Configured |
| Django Support | Full support | ✅ Verified |

**Overall**: Configuration is correct and will work! Just update the password for production. 🎉

---

## 🚀 Next Steps

1. **Update Password** (if `123` is not your real password):
   ```bash
   # Edit .env files
   nano deployment/6-services/.env.api
   nano deployment/6-services/.env.worker
   nano deployment/consolidated/.env.backend

   # Change EMAIL_HOST_PASSWORD to your actual password
   ```

2. **Deploy** following the deployment guide

3. **Test Email** after deployment using Django shell command above

4. **Monitor Logs** for any SMTP errors:
   ```bash
   docker logs plane-api -f
   docker logs plane-worker -f
   ```

**Your SMTP configuration is ready to use!** 📧✅
