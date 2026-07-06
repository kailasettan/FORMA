from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from app.routers import auth, profiles, stats, users, catalog, drops, scout, uploads

app = FastAPI(title="Forma API")


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(
    request: Request,
    exc: RequestValidationError,
) -> JSONResponse:
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
