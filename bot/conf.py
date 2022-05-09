import os

from dotenv import load_dotenv
from pathlib import Path


class Settings:

    def __init__(self, env_path=None):
        if env_path is None:
            env_path = Path(__file__).parent.parent / ".env"
        load_dotenv(env_path)

    def __getattr__(self, item: str) -> str:
        return os.environ[item]

    @staticmethod
    def get(item: str) -> str:
        return os.getenv(item)


settings = Settings()
