# syntax=docker/dockerfile:1.7
FROM node:22-bookworm AS build

# Install Bun and dependencies
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"
RUN corepack enable

WORKDIR /app
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY patches ./patches

# Install dependencies WITHOUT cache mounts to bypass Railway error
RUN NODE_OPTIONS=--max-old-space-size=2048 pnpm install --frozen-lockfile

COPY . .

# Build process
RUN pnpm build
RUN pnpm ui:build

# Final Runtime Stage
FROM node:22-bookworm-slim AS runtime
WORKDIR /app
ENV NODE_ENV=production

# Install essential runtime packages
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends procps hostname curl git openssl

# Copy build artifacts
COPY --from=build /app/dist ./dist
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/package.json .
COPY --from=build /app/openclaw.mjs .
COPY --from=build /app/extensions ./extensions
COPY --from=build /app/skills ./skills

# Security hardening
USER node

# Start Command
CMD ["node", "openclaw.mjs", "gateway", "--allow-unconfigured"]
