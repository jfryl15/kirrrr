# HPXPANEL — Railway deployment

## 1. Create the service

1. Push this repository to GitHub.
2. In Railway, create a new project and choose **Deploy from GitHub Repo**.
3. Select the HPXPANEL repository.
4. Railway will detect the included `railway.json` and `Dockerfile` automatically.

## 2. Required production database

For production, use PostgreSQL rather than the default SQLite file because Railway containers have ephemeral local storage.

Set:

```text
SQLALCHEMY_DATABASE_URL=postgresql+asyncpg://USER:PASSWORD@HOST:5432/DATABASE
```

Use Railway's PostgreSQL service and copy its connection URL into this variable (convert the scheme to `postgresql+asyncpg` if necessary).

## 3. Recommended variables

```text
ROLE=all-in-one
UVICORN_HOST=0.0.0.0
UVICORN_PROXY_HEADERS=true
UVICORN_FORWARDED_ALLOW_IPS=*
DEBUG=false
DOCS=false
RATE_LIMIT_ENABLED=true
```

Do **not** hard-code `PORT`. Railway injects it automatically and HPXPANEL reads it at startup.

## 4. First launch

Open the generated Railway public domain. The container runs database migrations before starting the application, and Railway checks `/health`.

If the deployment is healthy but you cannot log in, complete the application's initial setup flow rather than copying a local development database into production.

## 5. Custom domain

In Railway, open the service's **Settings → Networking → Public Networking**, generate a domain or attach your own domain, then wait for the TLS certificate to become active.

## 6. Important note about tunnels

Railway is suitable for the HPXPANEL control plane/web panel. It should not be treated as a replacement for dedicated VPN/Xray node infrastructure. Keep actual edge/tunnel nodes on appropriate VPS hosts and connect them to the panel.
