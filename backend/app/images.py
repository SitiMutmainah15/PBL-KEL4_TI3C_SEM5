"""Pemeriksaan berkas unggahan dan penyeragaman gambar sebelum dikirim ke Groq."""

from __future__ import annotations

import hashlib
import io
from collections import OrderedDict

from PIL import Image, UnidentifiedImageError

from . import config

ALLOWED_FORMATS = {"JPEG", "PNG", "WEBP"}


class InvalidImage(Exception):
    def __init__(self, message: str):
        super().__init__(message)
        self.message = message


def digest(data: bytes, label: str, confidence: float, locale: str) -> str:
    sha = hashlib.sha256()
    sha.update(data)
    sha.update(b"|")
    sha.update(f"{label}|{confidence:.4f}|{locale}|{config.GROQ_MODEL}".encode())
    return sha.hexdigest()


def prepare(data: bytes) -> tuple[bytes, str]:
    """Kembalikan (bytes JPEG, mime) yang sudah diperkecil bila perlu."""
    if not data:
        raise InvalidImage("Berkas gambar kosong.")
    if len(data) > config.MAX_UPLOAD_BYTES:
        raise InvalidImage("Ukuran foto melebihi batas unggah.")

    try:
        with Image.open(io.BytesIO(data)) as probe:
            if probe.format not in ALLOWED_FORMATS:
                raise InvalidImage("Format foto harus JPEG, PNG, atau WEBP.")
            probe.verify()
    except UnidentifiedImageError as error:
        raise InvalidImage("Berkas tidak dikenali sebagai gambar.") from error
    except InvalidImage:
        raise
    except Exception as error:
        raise InvalidImage("Berkas gambar rusak atau tidak lengkap.") from error

    try:
        with Image.open(io.BytesIO(data)) as source:
            frame = source.convert("RGB")
    except Exception as error:
        raise InvalidImage("Gambar tidak dapat dibaca ulang.") from error

    if max(frame.size) > config.MAX_IMAGE_EDGE:
        frame.thumbnail((config.MAX_IMAGE_EDGE, config.MAX_IMAGE_EDGE), Image.LANCZOS)

    buffer = io.BytesIO()
    frame.save(buffer, "JPEG", quality=85, optimize=True)
    return buffer.getvalue(), "image/jpeg"


class CaptionCache:
    """Cache kecil di memori agar foto yang sama tidak diulang ke Groq."""

    def __init__(self, limit: int):
        self._limit = max(1, limit)
        self._items: OrderedDict[str, dict] = OrderedDict()

    def get(self, key: str) -> dict | None:
        value = self._items.get(key)
        if value is None:
            return None
        self._items.move_to_end(key)
        return value

    def put(self, key: str, value: dict) -> None:
        self._items[key] = value
        self._items.move_to_end(key)
        while len(self._items) > self._limit:
            self._items.popitem(last=False)

    def clear(self) -> None:
        self._items.clear()

    def __len__(self) -> int:
        return len(self._items)
