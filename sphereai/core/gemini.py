from google import genai
from google.genai import types
from config import GEMINI_API_KEY, GEMINI_MODELS

_client = genai.Client(api_key=GEMINI_API_KEY)


def generate(contents: str, response_mime_type: str = "application/json") -> str:
    """
    Try each model in GEMINI_MODELS in order.
    Returns the raw response text from the first model that succeeds.
    Raises RuntimeError if all models fail.
    """
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
