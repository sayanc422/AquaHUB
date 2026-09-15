# syntax=docker/dockerfile:1.7
# ---------- build ----------
FROM python:3.11-slim-bookworm AS build
WORKDIR /build
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 PIP_NO_CACHE_DIR=1
# Dependency layer first: requirements.txt changes far less often than the rules.
COPY requirements.txt .
RUN python -m venv /venv && /venv/bin/pip install -r requirements.txt

# ---------- runtime ----------
# python:3.11-slim, not distroless.
#
# A deliberate divergence from the other four services, and worth naming rather
# than hiding: gcr.io/distroless/python3 ships a fixed interpreter and no pip,
# so uvicorn's native wheels (uvloop, httptools) have to be vendored in by hand.
# That is doable and it is a follow-up, not a claim made here.
#
# Cost: this image has a shell and a package manager in it, so it is the largest
# attack surface in the platform. The securityContext compensates as far as it
# can -- non-root, read-only root filesystem, all capabilities dropped -- but a
# shell in the image is a shell in the image.
FROM python:3.11-slim-bookworm
WORKDIR /app
COPY --from=build /venv /venv
COPY advisor ./advisor
# The rules ship in the image. They are versioned with the code and every answer
# names the version that produced it, so "which rules said no" is answerable
# from the response alone.
COPY rules ./rules

RUN useradd --uid 65532 --no-create-home --shell /usr/sbin/nologin nonroot
USER 65532:65532
ENV PATH="/venv/bin:$PATH" PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1
EXPOSE 8084
# One worker per pod. Scaling is the platform's job -- replicas, not processes --
# and a second worker here would double the memory for a service that is
# I/O-bound on one upstream call.
ENTRYPOINT ["uvicorn", "advisor.main:app", "--host", "0.0.0.0", "--port", "8084", "--workers", "1"]
