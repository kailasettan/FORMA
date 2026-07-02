from fastapi import FastAPI

from app.routers import auth, profiles, stats, users

app = FastAPI(title="Forma API")

app.include_router(auth.router)
app.include_router(users.router)
app.include_router(profiles.router)
app.include_router(stats.router)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
