#!/bin/bash
# Self-host helper: run the bundled mock, or the full upstream stack.
# Usage: ./tools/selfhost.sh [mock|upstream|logs|down]
set -e
MODE=${1:-mock}
case "$MODE" in
  mock)
    docker compose up -d --build
    docker compose ps
    echo "Mock API: http://localhost:5001/"
    ;;
  upstream)
    if [ ! -d /tmp/upstream-locket ]; then
      git clone --depth 1 https://github.com/doi2523/Client-Locket-Dio /tmp/upstream-locket
    fi
    cd /tmp/upstream-locket/apps/self-hosted
    for s in api storage web; do
      [ -f $s/.env.production ] || cp $s/.env.example $s/.env.production
    done
    echo "Edit api/.env.production, storage/.env.production, web/.env.production then run: docker compose up -d --build"
    ;;
  logs) docker compose logs -f ;;
  down) docker compose down ;;
  *) echo "usage: $0 [mock|upstream|logs|down]" ;;
esac
