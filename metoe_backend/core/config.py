from pydantic_settings import BaseSettings
from functools import lru_cache
import os


class Settings(BaseSettings):
    APP_NAME: str = "MetoE 全球云服务器管理平台"
    VERSION: str = "1.0.0"
    DEBUG: bool = True

    HOST: str = "0.0.0.0"
    PORT: int = 3000

    JWT_SECRET: str = os.getenv("JWT_SECRET", "metoe-cloud-platform-secret-key-2026-change-me")
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRE_HOURS: int = 24 * 7  # 7天

    DB_PATH: str = os.getenv("DB_PATH", os.path.join(os.path.dirname(__file__), "..", "data", "metoe.db"))

    DEFAULT_ROLE: str = "user"
    INITIAL_BALANCE: float = 0.00

    RATE_LIMIT_PER_MINUTE: int = 120

    CORS_ORIGINS: list = ["*"]

    class Config:
        env_file = ".env"


@lru_cache()
def get_settings() -> Settings:
    return Settings()
