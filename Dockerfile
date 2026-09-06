# syntax=docker/dockerfile:1

ARG PYTHON_VERSION=3.14

# ---------- Dashboard build ----------
FROM oven/bun:1 AS dashboard-builder
WORKDIR /src/dashboard

COPY dashboard/package.json dashboard/bun.lock ./
RUN bun install --frozen-lockfile

COPY dashboard/ ./
ENV VITE_BASE_API=/
RUN bun run build
RUN cp ./build/index.html ./build/404.html

# ---------- Python dependency build ----------
FROM ghcr.io/astral-sh/uv:python${PYTHON_VERSION}-bookworm-slim AS python-builder
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy UV_PYTHON_DOWNLOADS=0

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc python3-dev libc6-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY pyproject.toml uv.lock ./
COPY vendor ./vendor
RUN uv sync --frozen --no-install-project --no-dev

COPY . /build
RUN uv sync --frozen --no-dev

# Inject the frontend built inside this Docker image.
COPY --from=dashboard-builder /src/dashboard/build /build/dashboard/build

# ---------- Runtime ----------
ARG PYTHON_VERSION
FROM python:${PYTHON_VERSION}-slim-bookworm
WORKDIR /code

COPY --from=python-builder /build /code

ENV PATH="/code/.venv/bin:$PATH" \
    UVICORN_HOST=0.0.0.0 \
    UVICORN_PROXY_HEADERS=true \
    UVICORN_FORWARDED_ALLOW_IPS=* \
    UVICORN_HTTP_REDIRECT=false

EXPOSE 8000

# Runtime utilities. Docker socket access is not assumed on Railway.
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl iproute2 iptables iputils-ping \
    && rm -rf /var/lib/apt/lists/*

COPY cli_wrapper.sh /usr/bin/hpxpanel-cli
COPY tui_wrapper.sh /usr/bin/hpxpanel-tui
COPY healthcheck.sh /code/healthcheck.sh
RUN chmod +x /usr/bin/hpxpanel-cli /usr/bin/hpxpanel-tui /code/healthcheck.sh /code/start.sh \
    /code/scripts/hpx-pulse-agent.sh /code/scripts/hpx-tunnel-engine-install.sh 2>/dev/null || true

# The tunnel-engine release is optional for Railway. If the GitHub release asset is
# temporarily unavailable, the web panel still builds and starts normally.
ARG TARGETARCH
RUN mkdir -p /code/bundled/tunnel-engine \
    && ENGINE_VERSION="$(tr -d '[:space:]' < /code/scripts/hpx-tunnel-engine.version)" \
    && ENGINE_TAG="hpx-tunnel-engine-v${ENGINE_VERSION}" \
    && case "${TARGETARCH}" in amd64) ENGINE_ARCH=amd64 ;; arm64) ENGINE_ARCH=arm64 ;; *) ENGINE_ARCH=amd64 ;; esac \
    && ENGINE_ASSET="hpx-tunnel-engine_linux_${ENGINE_ARCH}.tar.gz" \
    && if curl -fsSL "https://github.com/pooyahpx/HPXPANEL/releases/download/${ENGINE_TAG}/${ENGINE_ASSET}" \
         -o "/code/bundled/tunnel-engine/${ENGINE_ASSET}"; then \
         echo "Bundled ${ENGINE_ASSET}"; \
       else \
         echo "WARNING: tunnel engine asset unavailable; continuing without bundled engine."; \
         rm -f "/code/bundled/tunnel-engine/${ENGINE_ASSET}"; \
       fi \
    && curl -fsSL "https://github.com/pooyahpx/HPXPANEL/releases/download/${ENGINE_TAG}/SHA256SUMS" \
         -o "/code/bundled/tunnel-engine/SHA256SUMS" || true

ENTRYPOINT ["/code/start.sh"]
