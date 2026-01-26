#!/bin/bash

docker rm -f no-code-pycaret 2>/dev/null || true
docker rm -f no-code-app       2>/dev/null || true
docker compose -p no-code-app pull
docker compose -p no-code-app down --remove-orphans  2>/dev/null
docker compose -p no-code-app up -d

