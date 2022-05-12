import os

from dotenv import load_dotenv
from pathlib import Path


class Settings:

    def __init__(self, env_path=None):
        environment = os.getenv("ENVIRONMENT", "PRODUCTION")
        if environment == "TESTING":
            env_file = ".test.env"
        else:
            env_file = ".env"
        if env_path is None:
            env_path = Path(__file__).parent.parent / env_file
        load_dotenv(env_path)

    def __getattr__(self, item: str) -> str:
        return os.environ[item]

    @staticmethod
    def get(item: str) -> str:
        return os.getenv(item)


settings = Settings()
