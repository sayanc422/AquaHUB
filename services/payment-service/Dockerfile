# syntax=docker/dockerfile:1.7
# ---------- build ----------
FROM rust:1.90-bookworm AS build
# Not rust-version from Cargo.toml (1.82, the MSRV for this crate's own code):
# Cargo.lock resolved a transitive dependency (home v0.5.12) whose manifest
# requires the edition2024 Cargo feature, stabilized in 1.85. The builder
# needs to be new enough for the lockfile, which is a stricter floor than the
# crate's own MSRV.
WORKDIR /build
# Dependency layer first. A Rust dependency build is the slowest step in this
# repository by a wide margin, and Cargo.toml changes far less often than src.
COPY Cargo.toml Cargo.lock ./
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    mkdir src && echo 'fn main() {}' > src/main.rs \
 && cargo build --release \
 && rm -rf src
COPY migrations ./migrations
COPY src ./src
# Touch main.rs so the stub build above does not fool Cargo into skipping it.
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    touch src/main.rs && cargo build --release

# ---------- runtime ----------
# distroless/cc, not distroless/static: this binary is dynamically linked
# against glibc (libc, libm, libgcc_s), because rustls' crypto backend brings C
# code with it. A fully static build via the musl target would allow
# distroless/static and a smaller image; it is a follow-up, not a claim made
# here.
#
# No shell either way, so `kubectl exec -- sh` does not work. Debug with
# `kubectl debug` and an ephemeral container.
FROM gcr.io/distroless/cc-debian12:nonroot
COPY --from=build /build/target/release/payment-service /app/payment-service
USER nonroot:nonroot
EXPOSE 8083
ENTRYPOINT ["/app/payment-service"]
