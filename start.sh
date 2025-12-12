#!/bin/bash

docker rm -f no-code-pycaret 2>/dev/null || true
docker rm -f no-code-app       2>/dev/null || true

docker compose -p no-code-app:latest pull
docker compose -p no-code-app down --remove-orphans
docker compose -p no-code-app up -d

