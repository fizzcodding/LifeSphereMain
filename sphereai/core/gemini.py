from google import genai
from google.genai import types
from config import GEMINI_API_KEY, GEMINI_MODELS

_client = genai.Client(api_key=GEMINI_API_KEY)


def generate(contents: str, response_mime_type: str = "application/json") -> str:
    last_error = None

    for model in GEMINI_MODELS:
        try:
            response = _client.models.generate_content(
                model=model,
                contents=contents,
                config=types.GenerateContentConfig(
                    response_mime_type=response_mime_type
                ),
            )
            return response.parsed if response.parsed else response.text
        except Exception as e:
            last_error = e
            continue

    raise RuntimeError(
        f"All Gemini models failed. Last error: {last_error}. "
        f"Models tried: {GEMINI_MODELS}"
    )


def transcribe(wav_bytes: bytes) -> str:
    last_error = None

    for model in GEMINI_MODELS:
        try:
            part = types.Part.from_bytes(data=wav_bytes, mime_type="audio/wav")
            response = _client.models.generate_content(
                model=model,
                contents=[
                    part,
                    "Transcribe the speech in this audio clip exactly. "
                    "Return only the spoken words with no commentary.",
                ],
                config=types.GenerateContentConfig(response_mime_type="text/plain"),
            )
            text = response.text or ""
            return text.strip()
        except Exception as e:
            last_error = e
            continue

    raise RuntimeError(
        f"All Gemini models failed during transcription. Last error: {last_error}. "
        f"Models tried: {GEMINI_MODELS}"
    )
