import os
from dotenv import load_dotenv

# Explicit .env path (sphereai/.env) resolved from this file's location so that
# loading works regardless of the process's current working directory.
_ENV_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env")
load_dotenv(_ENV_PATH)

# NOTE: values below are read once at import time by design — this is the
# project's config module and consumers (core/gemini.py) build clients from
# these constants. To pick up .env changes, restart the process.

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
