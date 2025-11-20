# Plane API Communication & CORS Configuration Guide

## Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [Frontend → Backend Communication](#frontend--backend-communication)
3. [CORS Configuration](#cors-configuration)
4. [Authentication Flow](#authentication-flow)
5. [WebSocket Communication](#websocket-communication)
6. [Security Considerations](#security-considerations)
7. [Troubleshooting](#troubleshooting)

---

## Architecture Overview

Plane uses a **microservices architecture** with separated frontend and backend services that communicate via HTTP/HTTPS and WebSockets.

```
┌─────────────────────────────────────────────────────────────────┐
│                    Internet (HTTPS)                             │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      ▼
         ┌────────────────────────┐
         │  Traefik (Dokploy)     │
         │  Reverse Proxy & SSL   │
         └────────────────────────┘
                      │
         ┌────────────┴────────────┐
         │                         │
         ▼                         ▼
┌──────────────────┐      ┌──────────────────┐
│   Frontend       │      │   API Backend    │
│ plane.mohdop.com │      │ plane-api.mohdop │
│                  │      │     .com         │
│ ┌──────────────┐ │      │                  │
│ │ Web App (/)  │ │      │ Django REST API  │
│ │ Admin (/god) │ │◄────┐│ Port 8000        │
│ │ Space (/sp)  │ │     ││                  │
│ │ Live (/live) │ │     │└──────────────────┘
│ └──────────────┘ │     │
│                  │     │
│ Nginx + React    │     │
│ Port 3000        │     │
└──────────────────┘     │
         │               │
         └───────────────┘
           API Calls
         (CORS Enabled)

┌─────────────────────────────────────────────────────────────────┐
│               Internal Docker Network (plane-network)           │
│  ┌──────────┐  ┌───────┐  ┌──────────┐  ┌────────┐            │
│  │PostgreSQL│  │ Redis │  │ RabbitMQ │  │ MinIO  │            │
│  │   :5432  │  │ :6379 │  │   :5672  │  │ :9000  │            │
│  └──────────┘  └───────┘  └──────────┘  └────────┘            │
└─────────────────────────────────────────────────────────────────┘
```

---

## Frontend → Backend Communication

### 1. **API Base URL Configuration**

The frontend apps are configured to communicate with the backend via environment variables:

**In `.env.frontend`:**
```bash
NEXT_PUBLIC_API_BASE_URL=https://plane-api.mohdop.com
VITE_API_BASE_URL=https://plane-api.mohdop.com
```

This URL is embedded into the JavaScript bundles during the build process.

### 2. **API Request Flow**

```
User Action (Browser)
    │
    ▼
Frontend JavaScript (plane.mohdop.com)
    │
    ▼
AJAX Request to: https://plane-api.mohdop.com/api/v1/...
    │
    ▼
Traefik Routing (based on Host header)
    │
    ▼
API Backend (plane-api:8000)
    │
    ▼
Django REST Framework
    │
    ▼
Database / Redis / MinIO
    │
    ▼
JSON Response
    │
    ▼
Frontend JavaScript
    │
    ▼
UI Update
```

### 3. **Example API Request**

**Frontend Code (JavaScript):**
```javascript
// API call from frontend
const response = await fetch(
  `${process.env.NEXT_PUBLIC_API_BASE_URL}/api/v1/workspaces/`,
  {
    method: 'GET',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    credentials: 'include', // Send cookies
  }
);
```

**Request Details:**
- **URL**: `https://plane-api.mohdop.com/api/v1/workspaces/`
- **Origin**: `https://plane.mohdop.com` (in the request header)
- **Method**: GET
- **Headers**: Authorization (JWT), Content-Type
- **Credentials**: Cookies included (for session management)

---

## CORS Configuration

### What is CORS?

**Cross-Origin Resource Sharing (CORS)** is a security feature that controls which domains can make requests to your API.

Since your frontend (`plane.mohdop.com`) and backend (`plane-api.mohdop.com`) are on **different domains**, CORS must be configured to allow cross-origin requests.

### 1. **Backend CORS Configuration**

**In `.env.api`:**
```bash
CORS_ALLOWED_ORIGINS=https://plane.mohdop.com
```

This tells the Django backend to:
1. Accept requests from `https://plane.mohdop.com`
2. Include CORS headers in responses
3. Allow credentials (cookies, authorization headers)

**Multiple Origins (if needed):**
```bash
CORS_ALLOWED_ORIGINS=https://plane.mohdop.com,https://app.example.com
```

### 2. **Django CORS Headers**

The API backend uses `django-cors-headers` package to handle CORS.

**In Django Settings (`plane/settings/production.py`):**
```python
INSTALLED_APPS = [
    ...
    'corsheaders',
    ...
]

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',  # Must be before CommonMiddleware
    'django.middleware.common.CommonMiddleware',
    ...
]

# CORS Configuration
CORS_ALLOWED_ORIGINS = os.environ.get('CORS_ALLOWED_ORIGINS', '').split(',')
CORS_ALLOW_CREDENTIALS = True  # Allow cookies and auth headers
CORS_ALLOW_HEADERS = [
    'accept',
    'accept-encoding',
    'authorization',
    'content-type',
    'dnt',
    'origin',
    'user-agent',
    'x-csrftoken',
    'x-requested-with',
]
```

### 3. **CORS Preflight Requests**

For certain requests (POST, PUT, DELETE with custom headers), browsers send a **preflight request** using the OPTIONS method.

**Preflight Request:**
```http
OPTIONS /api/v1/workspaces/ HTTP/1.1
Host: plane-api.mohdop.com
Origin: https://plane.mohdop.com
Access-Control-Request-Method: POST
Access-Control-Request-Headers: authorization, content-type
```

**Preflight Response:**
```http
HTTP/1.1 200 OK
Access-Control-Allow-Origin: https://plane.mohdop.com
Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS
Access-Control-Allow-Headers: authorization, content-type, x-csrftoken
Access-Control-Allow-Credentials: true
Access-Control-Max-Age: 86400
```

The browser caches this response for 24 hours (86400 seconds).

### 4. **Nginx CORS Headers (Frontend)**

The Nginx configuration in `nginx/combined-frontend.conf` includes security headers but **does NOT need CORS headers** because:
- Nginx serves static files (HTML, JS, CSS)
- JavaScript is executed in the browser
- The browser makes API requests directly to the backend

However, Nginx includes these security headers:
```nginx
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
```

---

## Authentication Flow

### 1. **JWT-Based Authentication**

Plane uses **JSON Web Tokens (JWT)** for authentication.

**Login Flow:**
```
1. User enters credentials in frontend
   │
   ▼
2. Frontend sends POST to /api/v1/auth/login/
   │
   ▼
3. Backend validates credentials
   │
   ▼
4. Backend returns JWT access token + refresh token
   │
   ▼
5. Frontend stores tokens (localStorage or memory)
   │
   ▼
6. Frontend includes token in Authorization header for all requests
```

**Example Login Request:**
```javascript
const response = await fetch(
  `${API_BASE_URL}/api/v1/auth/login/`,
  {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  }
);

const { access, refresh, user } = await response.json();

// Store tokens
localStorage.setItem('access_token', access);
localStorage.setItem('refresh_token', refresh);
```

**Example Authenticated Request:**
```javascript
const response = await fetch(
  `${API_BASE_URL}/api/v1/workspaces/`,
  {
    method: 'GET',
    headers: {
      'Authorization': `Bearer ${localStorage.getItem('access_token')}`,
      'Content-Type': 'application/json',
    },
  }
);
```

### 2. **Token Refresh Flow**

Access tokens expire after a short period (e.g., 15 minutes). The frontend must refresh them using the refresh token.

**Refresh Flow:**
```javascript
const response = await fetch(
  `${API_BASE_URL}/api/v1/auth/refresh/`,
  {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ refresh: localStorage.getItem('refresh_token') }),
  }
);

const { access } = await response.json();
localStorage.setItem('access_token', access);
```

---

## WebSocket Communication

### 1. **Live Server (Real-time Collaboration)**

The Live Server handles real-time collaborative editing using **WebSockets**.

**WebSocket URL:**
```
wss://plane.mohdop.com/live
```

**Connection Flow:**
```
1. User opens a document in the frontend
   │
   ▼
2. Frontend establishes WebSocket connection to /live
   │
   ▼
3. Traefik routes to Live Server (plane-live:3000)
   │
   ▼
4. Live Server validates JWT token with API backend
   │   (Internal HTTP request: plane-live → plane-api:8000)
   │
   ▼
5. Connection established
   │
   ▼
6. Real-time updates synchronized via Yjs CRDT
   │
   ▼
7. State persisted to Redis
```

### 2. **Live Server Authentication**

**In `.env.live`:**
```bash
# CRITICAL: Must match API SECRET_KEY!
LIVE_SERVER_SECRET_KEY=LtBkbgDqp-ZUlhkBjoO3kH6ftJpj6TcXR_w5HhKVsezQ_qK52pxAAUXokyJlwOUUh_U

# Internal API URL for JWT validation
API_BASE_URL=http://plane-api:8000

# CORS for WebSocket connections
ALLOWED_ORIGINS=https://plane.mohdop.com
```

**Why the same SECRET_KEY?**
- The Live Server validates JWTs issued by the API backend
- JWT signature verification requires the same secret key
- This ensures only authenticated users can connect

### 3. **WebSocket Request Example**

**Frontend Code:**
```javascript
const ws = new WebSocket(
  `wss://plane.mohdop.com/live?token=${accessToken}&doc=${documentId}`
);

ws.onopen = () => {
  console.log('Connected to Live Server');
};

ws.onmessage = (event) => {
  // Handle real-time updates
  const update = JSON.parse(event.data);
  applyUpdate(update);
};
```

---

## Security Considerations

### 1. **HTTPS Everywhere**

- All external communication uses HTTPS (handled by Traefik)
- Internal Docker network communication can use HTTP (not exposed to internet)

### 2. **CORS Restrictions**

- Only allow trusted origins in `CORS_ALLOWED_ORIGINS`
- Never use `*` (wildcard) in production
- Be specific: `https://plane.mohdop.com` (no trailing slash)

### 3. **Authentication & Authorization**

- Always validate JWT tokens on the backend
- Use HTTPS to protect tokens in transit
- Set appropriate token expiration times
- Implement token refresh mechanism

### 4. **Cookie Security**

**In `.env.api`:**
```bash
SESSION_COOKIE_SECURE=1  # Only send over HTTPS
CSRF_COOKIE_SECURE=1     # Only send over HTTPS
```

### 5. **Rate Limiting**

**Nginx Rate Limiting (Frontend):**
```nginx
limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;
limit_req zone=general burst=20 nodelay;
```

**API Rate Limiting (Backend):**
```python
# In .env.api
API_KEY_RATE_LIMIT=60/minute
```

### 6. **Input Validation**

- Always validate and sanitize user input on the backend
- Use Django's built-in validation and serializers
- Protect against SQL injection, XSS, CSRF

---

## Troubleshooting

### Common CORS Errors

#### Error: "Access to fetch at ... has been blocked by CORS policy"

**Cause:** The backend is not allowing requests from the frontend origin.

**Solution:**
1. Check `.env.api`:
   ```bash
   CORS_ALLOWED_ORIGINS=https://plane.mohdop.com
   ```
2. Ensure no trailing slash in the origin
3. Restart the API service after changing environment variables

#### Error: "The 'Access-Control-Allow-Origin' header contains multiple values"

**Cause:** Multiple CORS middleware or Nginx adding duplicate headers.

**Solution:**
1. Remove CORS headers from Nginx (only needed in Django)
2. Ensure `corsheaders.middleware.CorsMiddleware` is only listed once in Django settings

#### Error: "Credentials flag is 'true', but the 'Access-Control-Allow-Credentials' header is ''"

**Cause:** Backend not configured to allow credentials.

**Solution:**
1. Ensure `CORS_ALLOW_CREDENTIALS = True` in Django settings
2. Set `credentials: 'include'` in frontend fetch requests

### Common WebSocket Errors

#### Error: WebSocket connection failed

**Check:**
1. Live Server is running: `docker ps | grep plane-live`
2. Traefik routing is correct (path-based: `/live`)
3. CORS origin is correct in `.env.live`

#### Error: WebSocket authentication failed

**Check:**
1. `LIVE_SERVER_SECRET_KEY` matches `SECRET_KEY` from `.env.api`
2. JWT token is valid and not expired
3. API backend is accessible from Live Server (internal network)

### Debugging API Requests

**Use browser DevTools:**
1. Open Developer Tools (F12)
2. Go to Network tab
3. Filter by XHR/Fetch
4. Inspect request headers, response headers, and payload

**Check CORS headers in response:**
```
Access-Control-Allow-Origin: https://plane.mohdop.com
Access-Control-Allow-Credentials: true
```

**Check API logs:**
```bash
docker logs plane-api -f
```

---

## Summary

### Key Points

1. **Separate Domains**: Frontend and backend are on different domains, requiring CORS
2. **CORS Configuration**: Set `CORS_ALLOWED_ORIGINS` in `.env.api` to allow frontend requests
3. **HTTPS**: All external traffic uses HTTPS via Traefik
4. **JWT Authentication**: Tokens are included in Authorization header for API requests
5. **WebSocket**: Live Server uses same SECRET_KEY as API for JWT validation
6. **Security**: Enable secure cookies, rate limiting, and input validation

### Configuration Checklist

- [ ] `.env.api`: Set `CORS_ALLOWED_ORIGINS=https://plane.mohdop.com`
- [ ] `.env.api`: Set `API_BASE_URL=https://plane-api.mohdop.com`
- [ ] `.env.frontend`: Set `VITE_API_BASE_URL=https://plane-api.mohdop.com`
- [ ] `.env.live`: Set `ALLOWED_ORIGINS=https://plane.mohdop.com`
- [ ] `.env.live`: Set `LIVE_SERVER_SECRET_KEY` = same as API `SECRET_KEY`
- [ ] Traefik: Configure SSL certificates (Let's Encrypt)
- [ ] Test: Verify CORS headers in browser DevTools

---

**Need Help?**

- Check browser console for errors
- Inspect Network tab in DevTools
- Review Docker logs: `docker logs <container-name>`
- Verify environment variables in Dokploy
