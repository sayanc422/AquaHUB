# syntax=docker/dockerfile:1.7
FROM node:22-bookworm-slim AS build
WORKDIR /build
COPY package.json package-lock.json* ./
RUN npm ci || npm install
COPY tsconfig.json ./
COPY src ./src
RUN npm run build && npm prune --omit=dev

FROM gcr.io/distroless/nodejs22-debian12:nonroot
WORKDIR /app
COPY --from=build /build/node_modules ./node_modules
COPY --from=build /build/dist ./dist
COPY public ./public
USER nonroot:nonroot
EXPOSE 3000
CMD ["dist/server.js"]
