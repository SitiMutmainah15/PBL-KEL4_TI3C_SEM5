"""Panggilan ke Groq: satu permintaan visi yang menghasilkan caption dan saran foto."""

from __future__ import annotations

import json
import logging
from dataclasses import dataclass
from typing import Any

import httpx

from . import config

logger = logging.getLogger(__name__)

SYSTEM_PROMPT = """Anda asisten penyuluh pertanian untuk aplikasi EcoPlant yang membantu pengguna \
memeriksa daun pisang. Model klasifikasi di perangkat sudah memberi satu label dan skor. Tugas Anda \
hanya menulis teks pendamping dalam Bahasa Indonesia yang tenang dan konkret.

Aturan yang tidak boleh dilanggar:
1. Jangan pernah menyebut diagnosis pasti, persentase keyakinan baru, nama bahan aktif, dosis, atau \
   merek pestisida. Saran bersifat pengamatan dan tindakan awal yang aman.
2. Jangan mengarang gejala yang tidak terlihat. Jika gambar tidak jelas atau bukan daun pisang, \
   katakan apa adanya di field sesuai skema.
3. Panjang tiap field: ringkasan 2 sampai 4 kalimat, penanganan 2 sampai 4 kalimat, \
   saranFoto 1 sampai 3 kalimat.
4. Jangan memakai tanda pisah panjang (em dash), tanda seru, atau huruf kapital berlebihan.
5. Tulis dalam bentuk kalimat utuh, bukan daftar berbutir, dan tanpa judul atau markdown.
6. Selalu jujur bahwa ini prediksi model, bukan diagnosis. Sampaikan pengingat itu tepat satu kali \
   saja di seluruh jawaban, jangan diulang di field lain."""

RESPONSE_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "labelTerdeteksi": {"type": "string", "enum": list(config.LEAF_CLASSES)},
        "gambarSesuai": {"type": "boolean"},
        "ringkasan": {"type": "string"},
        "penanganan": {"type": "string"},
        "saranFoto": {"type": "string"},
    },
    "required": ["labelTerdeteksi", "gambarSesuai", "ringkasan", "penanganan", "saranFoto"],
    "additionalProperties": False,
}

LABEL_CONTEXT = {
    "healthy": (
        "Healthy",
        "Daun tidak menunjukkan pola bercak penyakit yang dikenali model.",
    ),
    "sigatoka": (
        "Sigatoka",
        "Bercak atau garis memanjang kekuningan hingga cokelat kehitaman, sering menyatu "
        "mengikuti arah tulang daun.",
    ),
    "cordana": (
        "Cordana",
        "Bercak cokelat keabu-abuan berbentuk lonjong dengan tepi lebih gelap, biasanya "
        "tidak mengikuti arah tulang daun.",
    ),
    "pestalotiopsis": (
        "Pestalotiopsis",
        "Bercak kecil kecokelatan yang melebar, sering dikelilingi halo kekuningan, dan "
        "dapat menyatu membentuk area kering.",
    ),
}


class GroqFailure(Exception):
    """Kegagalan yang aman ditampilkan ke pengguna."""

    def __init__(self, message: str, status_code: int = 502):
        super().__init__(message)
        self.message = message
        self.status_code = status_code


@dataclass(frozen=True)
class Caption:
    label_terdeteksi: str
    gambar_sesuai: bool
    ringkasan: str
    penanganan: str
    saran_foto: str

    def to_json(self) -> dict[str, Any]:
        return {
            "labelTerdeteksi": self.label_terdeteksi,
            "gambarSesuai": self.gambar_sesuai,
            "ringkasan": self.ringkasan,
            "penanganan": self.penanganan,
            "saranFoto": self.saran_foto,
        }


def _user_prompt(label: str, confidence: float, locale: str) -> str:
    display, traits = LABEL_CONTEXT[label]
    return (
        f"Label dari model di perangkat: {display} ({label}).\n"
        f"Skor keluaran model: {confidence * 100:.1f} persen. Skor ini bukan tingkat kepastian diagnosis.\n"
        f"Ciri umum kelas tersebut menurut dataset latih: {traits}\n"
        f"Bahasa keluaran: {locale}.\n\n"
        "Amati foto yang dilampirkan, lalu isi skema JSON. Isi labelTerdeteksi dengan label model "
        "di perangkat, kecuali pengamatan Anda pada foto jelas menunjukkan kelas lain; dalam hal itu "
        "tulis kelas yang Anda amati. Setel gambarSesuai ke false bila foto bukan daun pisang, terlalu "
        "gelap, buram, atau daunnya tidak terlihat utuh, dan tetap tulis teks yang berguna untuk kondisi "
        "itu. Field saranFoto berisi petunjuk cara memotret ulang agar ciri daun lebih mudah dibaca, "
        "misalnya arah cahaya, jarak, sudut, atau bagian daun yang perlu masuk bingkai."
    )


def _extract_json(payload: dict[str, Any]) -> dict[str, Any]:
    choices = payload.get("choices")
    if not isinstance(choices, list) or not choices:
        raise GroqFailure("Groq tidak mengembalikan pilihan jawaban.")
    message = choices[0].get("message") or {}
    content = message.get("content")
    if isinstance(content, list):
        content = "".join(
            part.get("text", "") for part in content if isinstance(part, dict)
        )
    if not isinstance(content, str) or not content.strip():
        raise GroqFailure("Groq mengembalikan jawaban kosong.")
    text = content.strip()
    if text.startswith("```"):
        text = text.split("\n", 1)[-1]
        text = text.rsplit("```", 1)[0]
    try:
        parsed = json.loads(text)
    except json.JSONDecodeError as error:
        logger.warning("Jawaban Groq bukan JSON: %s", text[:300])
        raise GroqFailure("Jawaban model tidak dapat dibaca.") from error
    if not isinstance(parsed, dict):
        raise GroqFailure("Jawaban model tidak sesuai format.")
    return parsed


def _clean(value: Any, field: str, limit: int) -> str:
    if not isinstance(value, str) or not value.strip():
        raise GroqFailure(f"Field {field} kosong pada jawaban model.")
    text = " ".join(value.split())
    if len(text) > limit:
        text = text[:limit].rstrip(" ,.;") + "."
    return text


def _parse(parsed: dict[str, Any], expected_label: str) -> Caption:
    label = parsed.get("labelTerdeteksi")
    if label not in config.LEAF_CLASSES:
        label = expected_label
    matches = parsed.get("gambarSesuai")
    if not isinstance(matches, bool):
        matches = True
    return Caption(
        label_terdeteksi=label,
        gambar_sesuai=matches,
        ringkasan=_clean(parsed.get("ringkasan"), "ringkasan", 700),
        penanganan=_clean(parsed.get("penanganan"), "penanganan", 700),
        saran_foto=_clean(parsed.get("saranFoto"), "saranFoto", 400),
    )


async def generate_caption(
    *,
    image_bytes: bytes,
    mime_type: str,
    label: str,
    confidence: float,
    locale: str = "id",
) -> Caption:
    if not config.GROQ_API_KEY:
        raise GroqFailure(
            "Layanan caption belum dikonfigurasi. Isi GROQ_API_KEY pada berkas .env backend.",
            status_code=503,
        )

    import base64

    data_url = f"data:{mime_type};base64,{base64.b64encode(image_bytes).decode('ascii')}"
    body = {
        "model": config.GROQ_MODEL,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": _user_prompt(label, confidence, locale)},
                    {"type": "image_url", "image_url": {"url": data_url}},
                ],
            },
        ],
        "temperature": 0.7,
        "top_p": 0.8,
        "max_completion_tokens": 900,
        "reasoning_effort": "none",
        "response_format": {
            "type": "json_schema",
            "json_schema": {
                "name": "ecoplant_caption",
                "strict": True,
                "schema": RESPONSE_SCHEMA,
            },
        },
    }

    try:
        async with httpx.AsyncClient(timeout=config.REQUEST_TIMEOUT_SECONDS) as client:
            response = await client.post(
                f"{config.GROQ_BASE_URL}/chat/completions",
                headers={
                    "Authorization": f"Bearer {config.GROQ_API_KEY}",
                    "Content-Type": "application/json",
                },
                json=body,
            )
    except httpx.TimeoutException as error:
        raise GroqFailure("Model terlalu lama menjawab. Coba lagi.", 504) from error
    except httpx.HTTPError as error:
        logger.warning("Koneksi Groq gagal: %s", error)
        raise GroqFailure("Layanan caption tidak dapat dihubungi.", 502) from error

    if response.status_code == 429:
        raise GroqFailure("Batas permintaan tercapai. Tunggu sebentar lalu coba lagi.", 429)
    if response.status_code == 401:
        logger.error("Groq menolak API key.")
        raise GroqFailure("Kunci layanan caption ditolak.", 502)
    if response.status_code >= 400:
        logger.warning("Groq %s: %s", response.status_code, response.text[:500])
        raise GroqFailure("Model gagal membuat caption. Coba lagi.", 502)

    try:
        payload = response.json()
    except ValueError as error:
        raise GroqFailure("Jawaban layanan tidak dapat dibaca.") from error

    return _parse(_extract_json(payload), label)
