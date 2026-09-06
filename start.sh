#!/usr/bin/env bash

ROLE="${ROLE:-all-in-one}"

# Railway injects PORT; config.py consumes it as UVICORN_PORT.
export UVICORN_HOST="${UVICORN_HOST:-0.0.0.0}"
export UVICORN_PROXY_HEADERS="${UVICORN_PROXY_HEADERS:-true}"
export UVICORN_FORWARDED_ALLOW_IPS="${UVICORN_FORWARDED_ALLOW_IPS:-*}"

if [ "${ROLE}" = "node" ]; then
    exec python node_worker.py
elif [ "${ROLE}" = "scheduler" ]; then
    exec python scheduler_worker.py
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting ${ROLE}..."
    python -m alembic upgrade head
    exit_code=$?

    if [ $exit_code -ne 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Database migrations failed"
        exit 1
    fi

    exec python main.py
fi