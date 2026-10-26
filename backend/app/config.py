import os
from pathlib import Path

from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parent.parent / ".env")


def _int(name: str, default: int) -> int:
    raw = os.environ.get(name)
    if raw is None or not raw.strip():
        return default
    try:
        return int(raw)
    except ValueError as error:
        raise RuntimeError(f"{name} harus berupa angka, bukan {raw!r}.") from error


GROQ_API_KEY = os.environ.get("GROQ_API_KEY", "").strip()
GROQ_MODEL = os.environ.get("GROQ_MODEL", "qwen/qwen3.8-27b").strip()
GROQ_BASE_URL = os.environ.get("GROQ_BASE_URL", "https://api.groq.com/openai/v1").rstrip("/")

MAX_UPLOAD_BYTES = _int("MAX_UPLOAD_BYTES", 8 * 1024 * 1024)
MAX_CONCURRENT_REQUESTS = _int("MAX_CONCURRENT_REQUESTS", 4)
CACHE_ENTRIES = _int("CACHE_ENTRIES", 256)
REQUEST_TIMEOUT_SECONDS = _int("REQUEST_TIMEOUT_SECONDS", 45)
MAX_IMAGE_EDGE = _int("MAX_IMAGE_EDGE", 1024)

ALLOWED_ORIGINS = [
    origin.strip()
    for origin in os.environ.get("ALLOWED_ORIGINS", "").split(",")
    if origin.strip()
]

LEAF_CLASSES = ("healthy", "sigatoka", "cordana", "pestalotiopsis")
