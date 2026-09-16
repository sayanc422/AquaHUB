# syntax=docker/dockerfile:1.7
# ---------- build ----------
FROM golang:1.25-bookworm AS build
WORKDIR /build
# dependency layer first: go.mod/go.sum rarely change, src changes every commit
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/root/.cache/go-build --mount=type=cache,target=/go/pkg/mod \
    go mod download
COPY . .
# CGO off: the binary must not need libc at runtime, because the runtime stage
# has no libc to link against. Trimpath keeps build-host paths out of panics.
RUN --mount=type=cache,target=/root/.cache/go-build --mount=type=cache,target=/go/pkg/mod \
    CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" \
        -o /out/notification-service ./cmd/notification-service

# ---------- runtime ----------
# static, not java21-debian12: this binary needs a CA bundle and /etc/passwd and
# nothing else, the same reasoning as inventory-service's own Dockerfile.
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/notification-service /app/notification-service
USER nonroot:nonroot
EXPOSE 8085
ENTRYPOINT ["/app/notification-service"]
