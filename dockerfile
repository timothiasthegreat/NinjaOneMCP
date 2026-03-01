# syntax=docker/dockerfile:1

##
## Build stage
##
FROM node:current-alpine AS build
WORKDIR /app

# Install dependencies first (better cache)
COPY package*.json ./
RUN npm ci

# Copy source and build TypeScript
COPY . .
RUN npm run build

##
## Runtime stage
##
FROM node:current-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production

# Install only production deps
COPY package*.json ./
RUN npm ci --omit=dev

# Copy compiled output
COPY --from=build /app/dist ./dist

# Include runtime metadata files (safe to include; small footprint)
COPY server.json ./server.json
COPY manifest.json ./manifest.json

# Default ports per upstream docs
EXPOSE 3000 3001

# Default runtime behavior: HTTP transport on 3000
ENV MCP_MODE=http \
    HTTP_PORT=3000 \
    SSE_PORT=3001

# HTTP health endpoint is documented for HTTP transport
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+process.env.HTTP_PORT+'/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

# Default to HTTP mode
CMD ["npm", "run", "start:http"]