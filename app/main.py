from fastapi import FastAPI

from app.routers import auth, profiles, stats, users, catalog, drops, scout

app = FastAPI(title="Forma API")

app.include_router(auth.router)
app.include_router(users.router)
app.include_router(profiles.router)
app.include_router(stats.router)
app.include_router(catalog.router)
app.include_router(drops.router)
app.include_router(scout.router)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
