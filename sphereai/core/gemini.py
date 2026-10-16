import json
import threading
from google import genai
from google.genai import types
from config import GEMINI_API_KEY, GEMINI_MODELS

_client = genai.Client(api_key=GEMINI_API_KEY)
_CALL_TIMEOUT = 30


def _call_with_timeout(fn, timeout: float):
    result = [None]
    error = [None]

    def _run():
        try:
            result[0] = fn()
        except Exception as exc:
            error[0] = exc

    t = threading.Thread(target=_run, daemon=True)
    t.start()
    t.join(timeout)

    if t.is_alive():
        raise TimeoutError(f'Gemini call exceeded {timeout}s timeout')
    if error[0] is not None:
        raise error[0]
    return result[0]


def generate(contents: str, response_mime_type: str = 'application/json') -> str:
    last_error = None

    for model in GEMINI_MODELS:
        try:
            def _call(m=model):
                return _client.models.generate_content(
                    model=m,
                    contents=contents,
                    config=types.GenerateContentConfig(
                        response_mime_type=response_mime_type,
                    ),
                )

            response = _call_with_timeout(_call, _CALL_TIMEOUT)

            if response.parsed is not None:
                return response.parsed

            text = response.text
            if text:
                try:
                    json.loads(text)
                except (json.JSONDecodeError, ValueError) as parse_err:
                    raise ValueError(
                        f'Gemini returned non-JSON text for model {model}: {parse_err}'
                    )
                return text

            raise ValueError(f'Gemini returned empty response for model {model}')

        except Exception as e:
            last_error = e
            continue

    raise RuntimeError(
        f'All Gemini models failed. Last error: {last_error}. '
        f'Models tried: {GEMINI_MODELS}'
    )


def transcribe(wav_bytes: bytes) -> str:
    last_error = None

    for model in GEMINI_MODELS:
        try:
            def _call(m=model):
                part = types.Part.from_bytes(data=wav_bytes, mime_type='audio/wav')
                return _client.models.generate_content(
                    model=m,
                    contents=[
                        part,
                        'Transcribe the speech in this audio clip exactly. '
                        'Return only the spoken words with no commentary.',
                    ],
                    config=types.GenerateContentConfig(response_mime_type='text/plain'),
                )

            response = _call_with_timeout(_call, _CALL_TIMEOUT)
            text = response.text or ''
            return text.strip()

        except Exception as e:
            last_error = e
            continue

    raise RuntimeError(
        f'All Gemini models failed during transcription. Last error: {last_error}. '
        f'Models tried: {GEMINI_MODELS}'
    )
