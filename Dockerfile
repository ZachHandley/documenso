###########################
#     BASE CONTAINER      #
###########################
FROM node:18-alpine AS base

###########################
#    BUILDER CONTAINER    #
###########################
FROM base AS builder

# Check https://github.com/nodejs/docker-node/tree/b4117f9333da4138b03a546ec926ef50a31506c3#nodealpine to understand why libc6-compat might be needed.
RUN apk add --no-cache libc6-compat
RUN apk add --no-cache jq
WORKDIR /app

COPY . .

RUN TURBO_VERSION="$(npm list --package-lock-only --json turbo | jq -r '.dependencies.turbo.version')"
RUN npm install -g "turbo@$TURBO_VERSION"

# Outputs to the /out folder
# source: https://turbo.build/repo/docs/reference/command-line-reference/prune#--docker
RUN turbo prune --scope=@documenso/web --docker

###########################
#   INSTALLER CONTAINER   #
###########################
FROM base AS installer

# Check https://github.com/nodejs/docker-node/tree/b4117f9333da4138b03a546ec926ef50a31506c3#nodealpine to understand why libc6-compat might be needed.
RUN apk add --no-cache libc6-compat
RUN apk add --no-cache jq
# Required for node_modules/aws-crt
RUN apk add --no-cache make cmake g++
WORKDIR /app

# Disable husky from installing hooks
ENV HUSKY 0
ENV DOCKER_OUTPUT 1
ENV NEXT_TELEMETRY_DISABLED 1

# Encryption keys
ARG NEXT_PRIVATE_ENCRYPTION_KEY="CAFEBABE"
ENV NEXT_PRIVATE_ENCRYPTION_KEY="$NEXT_PRIVATE_ENCRYPTION_KEY"

ARG NEXT_PRIVATE_ENCRYPTION_SECONDARY_KEY="DEADBEEF"
ENV NEXT_PRIVATE_ENCRYPTION_SECONDARY_KEY="$NEXT_PRIVATE_ENCRYPTION_SECONDARY_KEY"


# Uncomment and use build args to enable remote caching
# ARG TURBO_TEAM
# ENV TURBO_TEAM=$TURBO_TEAM
# ARG TURBO_TOKEN
# ENV TURBO_TOKEN=$TURBO_TOKEN

# First install the dependencies (as they change less often)
COPY .gitignore .gitignore
COPY --from=builder /app/out/json/ .
COPY --from=builder /app/out/package-lock.json ./package-lock.json

RUN npm ci

# Then copy all the source code (as it changes more often)
COPY --from=builder /app/out/full/ .
# Finally copy the turbo.json file so that we can run turbo commands
COPY turbo.json turbo.json

RUN TURBO_VERSION="$(npm list --package-lock-only --json turbo | jq -r '.dependencies.turbo.version')"
RUN npm install -g "turbo@$TURBO_VERSION"

RUN turbo run build --filter=@documenso/web...

###########################
#     RUNNER CONTAINER    #
###########################
FROM base AS runner

WORKDIR /app

RUN npm install -g dotenv-cli
RUN npm install -g prisma
RUN apk add --no-cache tini
# Don't run production as root
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

USER nextjs

COPY --from=installer --chown=nextjs:nodejs /app/apps/web/next.config.js .
COPY --from=installer --chown=nextjs:nodejs /app/apps/web/package.json .

# Automatically leverage output traces to reduce image size
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=installer --chown=nextjs:nodejs /app/apps/web/.next/standalone ./
COPY --from=installer --chown=nextjs:nodejs /app/apps/web/.next/static ./apps/web/.next/static

# Ensure the file is copied to the correct location
COPY --chown=nextjs:nodejs compose-entrypoint.sh /apps/
COPY --chown=nextjs:nodejs package-lock.json .

# Make sure the script is executable
# RUN chmod +x compose-entrypoint.sh

# Correctly set the entry point with the full path
ENTRYPOINT ["/sbin/tini", "--", "/apps/compose-entrypoint.sh"]

EXPOSE 3000
ENV PORT 3000
