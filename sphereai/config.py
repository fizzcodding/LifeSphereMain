import os
from dotenv import load_dotenv
load_dotenv()

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")

if not GEMINI_API_KEY:
    raise ValueError("GEMINI_API_KEY not set in .env")

# Ordered list of models to try. Primary first, then fallbacks in order.
GEMINI_MODELS = [
    m for m in [
        os.getenv("GEMINI_MODEL"),
        os.getenv("GEMINI_FALLBACK"),
        os.getenv("GEMINI_FALLBACKS"),
        os.getenv("GEMINI_FALLBACKT"),
    ] if m
]

if not GEMINI_MODELS:
    raise ValueError("No Gemini model configured in .env")
