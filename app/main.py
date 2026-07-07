import logging
import os
import subprocess
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from app.routers import auth, profiles, stats, users, catalog, drops, scout, uploads
from app.schemas import USERNAME_ERROR

logger = logging.getLogger(__name__)


def _current_commit() -> str:
    for env_name in (
        "RAILWAY_GIT_COMMIT_SHA",
        "SOURCE_COMMIT",
        "GIT_COMMIT_SHA",
        "COMMIT_SHA",
    ):
        value = os.getenv(env_name)
        if value:
            return value

    try:
        return subprocess.check_output(
            ["git", "rev-parse", "HEAD"],
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=1,
        ).strip()
    except Exception:
        return "unknown"


@asynccontextmanager
async def lifespan(app: FastAPI):
    auth.log_resend_config_state()
    logger.warning("Flutter default API base URL is configured in forma_app/lib/data/api_config.dart")
    yield


app = FastAPI(title="Forma API", lifespan=lifespan)


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(
    request: Request,
    exc: RequestValidationError,
) -> JSONResponse:
    if any(USERNAME_ERROR in str(error.get("msg", "")) for error in exc.errors()):
        return JSONResponse(status_code=422, content={"detail": USERNAME_ERROR})

    errors = []
    for error in exc.errors():
        loc = error.get("loc", ())
        field_path = ".".join(str(part) for part in loc if part != "body")
        message = error.get("msg", "invalid value")
        errors.append(f"{field_path}: {message}" if field_path else str(message))
    return JSONResponse(
        status_code=422,
        content={"detail": "Invalid request: " + "; ".join(errors)},
    )

app.include_router(auth.router)
app.include_router(users.router)
app.include_router(profiles.router)
app.include_router(stats.router)
app.include_router(catalog.router)
app.include_router(drops.router)
app.include_router(scout.router)
app.include_router(uploads.router)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/debug/version")
def debug_version() -> dict[str, str | bool]:
    return {
        "status": "ok",
        "environment": auth.settings.app_env,
        "commit": _current_commit(),
        "resend_key_present": bool(auth.settings.resend_api_key),
        "from_email_configured": bool(auth.settings.from_email),
        "from_name_configured": bool(auth.settings.from_name),
    }
