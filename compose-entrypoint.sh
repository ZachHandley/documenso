#!/usr/bin/env sh

# cd /app

ls -la .

npm ci

npm run prisma:migrate-dev --schema packages/prisma/schema.prisma

HOSTNAME=0.0.0.0 PORT=3000 node apps/web/server.js
