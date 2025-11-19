# Plane Deployment on Dokploy

This directory contains the configuration files for deploying Plane on Dokploy with separated Frontend and Backend services.

## 1. Backend Deployment

1.  Create a new **Application** or **Compose** project in Dokploy.
2.  Use the content of `dokploy-backend-gemini.yml`.
3.  **Environment Variables**:
    *   Update `WEB_URL` and `CORS_ALLOWED_ORIGINS` to match your planned Frontend domain (e.g., `https://plane.yourdomain.com`).
    *   Update `API_BASE_URL` to match your planned Backend domain (e.g., `https://api.plane.yourdomain.com`).
    *   **IMPORTANT**: Change `SECRET_KEY`, `POSTGRES_PASSWORD`, etc., to secure values.
4.  **Domains**:
    *   Add your backend domain (e.g., `api.plane.yourdomain.com`) in Dokploy.
    *   Map it to the `api` service (Port `8000`).
    *   Enable HTTPS (Let's Encrypt).

## 2. Frontend Deployment

1.  Create a second **Application** or **Compose** project in Dokploy.
2.  Use the content of `dokploy-frontend-gemini.yml`.
3.  **Environment Variables**:
    *   Update `NEXT_PUBLIC_API_BASE_URL` to match your Backend domain (e.g., `https://api.plane.yourdomain.com`).
    *   Update `NEXT_PUBLIC_WEB_BASE_URL` to match your Frontend domain.
4.  **Domains**:
    *   Add your frontend domain (e.g., `plane.yourdomain.com`) in Dokploy.
    *   Map it to the `web` service (Port `3000`).
    *   Enable HTTPS (Let's Encrypt).

## 3. Live Service (WebSockets)

The `live` service is included in the Frontend stack. Dokploy (via Traefik) supports WebSockets automatically.
*   Ensure your Frontend domain routing allows traffic to reach the `live` container if it's on a separate path, or if it's bundled, it should just work.
