"""aquatics-advisor: the service that says whether a tank will work.

Python, and not because it is easy. The rules in `rules/rules.yaml` change far
more often than the code that applies them, and they are meant to be edited by
somebody who keeps fish. A language and a deployment cadence that suit "change
a threshold and ship it this afternoon" are the point; the rest of the platform
is built for services whose behaviour changes slowly.

It owns no data. Species care profiles belong to catalog-service, and the
advisor reads them.
"""

from __future__ import annotations

import json
import logging
import os
import pathlib
import sys

import yaml
from fastapi import FastAPI

from advisor.api import request_logger, router
from advisor.catalog import CatalogClient
from advisor.rules import Rules


class JsonFormatter(logging.Formatter):
    """JSON to stdout, like every other service here.

    The container writes and the platform collects; a service that manages its
    own log files needs a writable filesystem and a rotation policy, and this
    one has neither.
    """

    def format(self, record: logging.LogRecord) -> str:
        payload = {
            "time": self.formatTime(record),
            "level": record.levelname,
            "logger": record.name,
            "msg": record.getMessage(),
        }
        for key in ("method", "path", "status", "duration_ms"):
            if hasattr(record, key):
                payload[key] = getattr(record, key)
        return json.dumps(payload)


def configure_logging() -> None:
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JsonFormatter())
    root = logging.getLogger()
    root.handlers = [handler]
    root.setLevel(os.environ.get("LOG_LEVEL", "INFO"))


def load_rules(path: pathlib.Path) -> Rules:
    """Read the rules once, at startup.

    Deliberately not reloaded on a timer. A rules file that changes underneath a
    running service means two pods can answer the same question differently for
    as long as the rollout takes, and "why did it say yes yesterday" becomes
    unanswerable. A change to the rules is a deployment, and the version is in
    every response so an answer can be traced back to the file that produced it.
    """
    raw = yaml.safe_load(path.read_text())
    if "version" not in raw:
        raise ValueError(f"{path} has no version; every answer has to name the rules that made it")
    return Rules(raw)


def create_app() -> FastAPI:
    configure_logging()
    app = FastAPI(
        title="aquatics-advisor",
        summary="Whether a tank will work, and why not.",
        docs_url="/docs",
    )

    rules_path = pathlib.Path(os.environ.get("RULES_PATH", "rules/rules.yaml"))
    app.state.rules = load_rules(rules_path)
    app.state.catalog = CatalogClient(
        base_url=os.environ.get("CATALOG_BASE_URL", "http://catalog-service:8080"),
        timeout_s=float(os.environ.get("CATALOG_TIMEOUT_S", "2.0")),
        ttl_s=float(os.environ.get("CATALOG_CACHE_TTL_S", "300")),
    )

    request_logger(app)
    app.include_router(router)

    logging.getLogger("advisor").info(
        f"loaded rules v{app.state.rules.version} from {rules_path}"
    )
    return app


app = create_app()
