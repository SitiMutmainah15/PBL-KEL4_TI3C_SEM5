"""Endpoint HTTP yang dipakai aplikasi Flutter."""

from __future__ import annotations

import asyncio
import logging

from fastapi import FastAPI, File, Form, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from . import config
from .groq_client import GroqFailure, generate_caption
from .images import CaptionCache, InvalidImage, digest, prepare

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(name)s %(message)s")
logger = logging.getLogger("ecoplant")

app = FastAPI(title="EcoPlant Caption API", version="1.0.0")

if config.ALLOWED_ORIGINS:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=config.ALLOWED_ORIGINS,
        allow_methods=["POST", "GET"],
        allow_headers=["Content-Type"],
    )

cache = CaptionCache(config.CACHE_ENTRIES)
limiter = asyncio.Semaphore(config.MAX_CONCURRENT_REQUESTS)


@app.get("/health")
async def health() -> dict:
    return {
        "status": "ok",
        "model": config.GROQ_MODEL,
        "captionReady": bool(config.GROQ_API_KEY),
    }


@app.post("/v1/caption")
async def caption(
    image: UploadFile = File(...),
    label: str = Form(...),
    confidence: float = Form(...),
    locale: str = Form("id"),
) -> JSONResponse:
    if label not in config.LEAF_CLASSES:
        return JSONResponse(
            {"error": "Label tidak dikenal."},
            status_code=422,
        )
    if not 0.0 <= confidence <= 1.0:
        return JSONResponse(
            {"error": "Confidence harus di antara 0 dan 1."},
            status_code=422,
        )

    data = await image.read(config.MAX_UPLOAD_BYTES + 1)
    try:
        prepared, mime = prepare(data)
    except InvalidImage as error:
        return JSONResponse({"error": error.message}, status_code=415)

    key = digest(prepared, label, confidence, locale)
    cached = cache.get(key)
    if cached is not None:
        return JSONResponse({**cached, "cached": True})

    try:
        async with limiter:
            result = await generate_caption(
                image_bytes=prepared,
                mime_type=mime,
                label=label,
                confidence=confidence,
                locale=locale,
            )
    except GroqFailure as error:
        return JSONResponse({"error": error.message}, status_code=error.status_code)

    payload = result.to_json()
    cache.put(key, payload)
    return JSONResponse({**payload, "cached": False})
