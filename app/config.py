from pydantic import AliasChoices, Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_url: str = "postgresql+psycopg://postgres:postgres@localhost:5432/forma"
    secret_key: str = Field(
        default="change-me-in-production",
        validation_alias=AliasChoices("JWT_SECRET_KEY", "SECRET_KEY"),
    )
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 60 * 24 * 7

    # Cloudinary Config
    cloudinary_cloud_name: str = "nyuzzi3x"
    cloudinary_api_key: str = Field(default="", validation_alias=AliasChoices("CLOUDINARY_API_KEY"))
    cloudinary_api_secret: str = Field(default="", validation_alias=AliasChoices("CLOUDINARY_API_SECRET"))

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    @property
    def sqlalchemy_database_url(self) -> str:
        if self.database_url.startswith("postgresql://"):
            return self.database_url.replace("postgresql://", "postgresql+psycopg://", 1)
        return self.database_url


settings = Settings()
