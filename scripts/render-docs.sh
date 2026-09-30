#!/usr/bin/env bash
# Regenerates the diagram SVGs and re-renders docs/architecture.pdf.
#
#   ./scripts/render-docs.sh
#
# Why a container: this machine has no native Linux node or browser, only a
# Windows interop shim that cannot run Chromium from a WSL path. The
# playwright image already carries a matching Chromium, so the PDF comes out
# the same on any machine with Docker. npm fetches the playwright package on
# each run (a few seconds, needs the internet); the browser itself is in the image.
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE=mcr.microsoft.com/playwright:v1.48.0-jammy

log() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }

log "generating diagrams"
python3 "${ROOT}/docs/diagrams/generate.py"

log "rendering docs/architecture.pdf (in ${IMAGE})"
# --user keeps the PDF owned by you rather than root; HOME=/tmp because that
# UID has no home directory inside the image.
docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp \
  -v "${ROOT}/docs":/docs -w /tmp "${IMAGE}" bash -c '
    npm init -y >/dev/null 2>&1
    npm install --silent playwright@1.48.0 >/dev/null 2>&1
    node -e "
      const { chromium } = require(\"playwright\");
      (async () => {
        const b = await chromium.launch();
        const p = await b.newPage();
        await p.goto(\"file:///docs/architecture-pdf.html\", { waitUntil: \"load\" });
        // @page in the HTML sets the sheet size; printBackground keeps the dark theme.
        await p.pdf({ path: \"/docs/architecture.pdf\", preferCSSPageSize: true, printBackground: true });
        await b.close();
      })().catch(e => { console.error(e); process.exit(1); });
    "'

log "done: $(du -h "${ROOT}/docs/architecture.pdf" | cut -f1)  docs/architecture.pdf"
