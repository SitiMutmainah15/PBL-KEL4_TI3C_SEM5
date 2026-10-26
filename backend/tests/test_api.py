from __future__ import annotations

import io
import json
import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app import config, groq_client, images, main  # noqa: E402


def png_bytes(size=(64, 48), color=(90, 140, 60)) -> bytes:
    buffer = io.BytesIO()
    Image.new("RGB", size, color).save(buffer, "PNG")
    return buffer.getvalue()


def groq_reply(payload: dict) -> dict:
    return {"choices": [{"message": {"content": json.dumps(payload)}}]}


@pytest.fixture(autouse=True)
def reset_state(monkeypatch):
    monkeypatch.setattr(config, "GROQ_API_KEY", "test-key")
    main.cache.clear()
    yield
    main.cache.clear()


@pytest.fixture
def client():
    return TestClient(main.app)


def post(client, *, label="sigatoka", confidence=0.9, data=None, name="leaf.png"):
    return client.post(
        "/v1/caption",
        files={"image": (name, data if data is not None else png_bytes(), "image/png")},
        data={"label": label, "confidence": str(confidence), "locale": "id"},
    )


def test_health_reports_caption_readiness(client):
    body = client.get("/health").json()
    assert body["status"] == "ok"
    assert body["captionReady"] is True


def test_caption_returns_groq_fields(client, monkeypatch):
    seen = {}

    async def fake_generate(**kwargs):
        seen.update(kwargs)
        return groq_client.Caption(
            label_terdeteksi="sigatoka",
            gambar_sesuai=True,
            ringkasan="Ringkasan.",
            penanganan="Penanganan.",
            saran_foto="Saran foto.",
        )

    monkeypatch.setattr(main, "generate_caption", fake_generate)
    response = post(client, confidence=0.876)

    assert response.status_code == 200
    body = response.json()
    assert body["ringkasan"] == "Ringkasan."
    assert body["saranFoto"] == "Saran foto."
    assert body["cached"] is False
    assert seen["label"] == "sigatoka"
    assert seen["mime_type"] == "image/jpeg"
    assert seen["confidence"] == pytest.approx(0.876)


def test_same_photo_is_served_from_cache(client, monkeypatch):
    calls = 0

    async def fake_generate(**kwargs):
        nonlocal calls
        calls += 1
        return groq_client.Caption("healthy", True, "A.", "B.", "C.")

    monkeypatch.setattr(main, "generate_caption", fake_generate)
    first = post(client, label="healthy", confidence=0.99)
    second = post(client, label="healthy", confidence=0.99)

    assert first.json()["cached"] is False
    assert second.json()["cached"] is True
    assert calls == 1


def test_rejects_unknown_label_and_bad_confidence(client):
    assert post(client, label="mosaic").status_code == 422
    assert post(client, confidence=1.4).status_code == 422


def test_rejects_non_image_upload(client):
    response = post(client, data=b"not an image at all")
    assert response.status_code == 415


def test_missing_key_returns_503(client, monkeypatch):
    monkeypatch.setattr(config, "GROQ_API_KEY", "")
    response = post(client)
    assert response.status_code == 503


def test_groq_rate_limit_maps_to_429(client, monkeypatch):
    async def fake_generate(**kwargs):
        raise groq_client.GroqFailure("Batas permintaan tercapai.", 429)

    monkeypatch.setattr(main, "generate_caption", fake_generate)
    response = post(client)
    assert response.status_code == 429
    assert "Batas" in response.json()["error"]


def test_prepare_downscales_large_image():
    data = png_bytes(size=(2400, 1600))
    prepared, mime = images.prepare(data)
    assert mime == "image/jpeg"
    with Image.open(io.BytesIO(prepared)) as result:
        assert max(result.size) == config.MAX_IMAGE_EDGE


def test_digest_changes_with_label():
    data = png_bytes()
    first = images.digest(data, "healthy", 0.5, "id")
    second = images.digest(data, "sigatoka", 0.5, "id")
    assert first != second


def test_parse_falls_back_to_expected_label():
    caption = groq_client._parse(
        {
            "labelTerdeteksi": "mosaic",
            "gambarSesuai": "yes",
            "ringkasan": "A",
            "penanganan": "B",
            "saranFoto": "C",
        },
        "cordana",
    )
    assert caption.label_terdeteksi == "cordana"
    assert caption.gambar_sesuai is True


def test_parse_rejects_empty_field():
    with pytest.raises(groq_client.GroqFailure):
        groq_client._parse(
            {
                "labelTerdeteksi": "healthy",
                "gambarSesuai": True,
                "ringkasan": "  ",
                "penanganan": "B",
                "saranFoto": "C",
            },
            "healthy",
        )
