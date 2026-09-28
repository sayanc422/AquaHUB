# syntax=docker/dockerfile:1.7
FROM node:22-bookworm-slim AS build
WORKDIR /build
COPY package.json package-lock.json* ./
RUN npm ci || npm install
COPY tsconfig.json ./
COPY src ./src
RUN npm run build && npm prune --omit=dev

# Card-sized WebP copies of every photograph. Built here rather than committed:
# see scripts/image-variants.py for why a derived file does not belong in Git.
FROM python:3.12-slim AS variants
RUN pip install --no-cache-dir pillow==11.*
COPY scripts/image-variants.py /image-variants.py
COPY public /public
RUN python /image-variants.py /public /variants

FROM gcr.io/distroless/nodejs22-debian12:nonroot
WORKDIR /app
COPY --from=build /build/node_modules ./node_modules
COPY --from=build /build/dist ./dist
COPY public ./public
COPY --from=variants /variants ./public/variants
# The promise that public/variants exists. Off by default so `npm run dev`
# against a bare checkout still shows photographs rather than a page of
# placeholders for files that were never generated.
ENV IMAGE_VARIANTS=1
USER nonroot:nonroot
EXPOSE 3000
CMD ["dist/server.js"]
