import os
import getpass
from agents.language_agent import LanguageAgent
from agents.biology_agent import BiologyAgent, mock_vitals
from agents.voice_agent import VoiceAgent, mock_voice
from agents.response_agent import ResponseAgent
from agents.emotional_agent import EmotionalAgent
from fusion.emotional_fusion import EmotionalFusion
from core.spherecore_client import SphereCoreClient

print(r"""
███████╗██████╗ ██╗  ██╗███████╗██████╗ ███████╗ █████╗ ██████╗
██╔════╝██╔══██╗██║  ██║██╔════╝██╔══██╗██╔════╝██╔══██╗  ██╔═╝
███████╗██████╔╝███████║█████╗  ██████╔╝█████╗  ███████║  ██║
╚════██║██╔═══╝ ██╔══██║██╔══╝  ██╔══██╗██╔══╝  ██╔══██║  ██║
███████║██║     ██║  ██║███████╗██║  ██║███████╗██║  ██║██████╗
╚══════╝╚═╝     ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═════╝
""")

lang_agent = LanguageAgent()
bio_agent = BiologyAgent()
voice_agent = VoiceAgent()
emotional_agent = EmotionalAgent()
fusion = EmotionalFusion()
response_agent = ResponseAgent()
spherecore = SphereCoreClient()

_firebase_ready = False
_ENV_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env")


def _save_credentials(email: str, password: str):
    try:
        with open(_ENV_PATH, "r") as f:
            lines = f.readlines()

        keys_to_update = {"FIREBASE_EMAIL": email, "FIREBASE_PASSWORD": password}
        updated = {k: False for k in keys_to_update}
        new_lines = []

        for line in lines:
            key = line.split("=")[0].strip()
            if key in keys_to_update:
                new_lines.append(f"{key}={keys_to_update[key]}\n")
                updated[key] = True
            else:
                new_lines.append(line)

        for key, value in keys_to_update.items():
            if not updated[key]:
                new_lines.append(f"{key}={value}\n")

        with open(_ENV_PATH, "w") as f:
            f.writelines(new_lines)

    except Exception as e:
        print(f"[SphereCore] Could not save credentials to .env: {e}")


def _try_login(email: str, password: str, save: bool = False) -> bool:
    global _firebase_ready
    try:
        spherecore.authenticate(email, password)
        _firebase_ready = True
        if save:
            _save_credentials(email, password)
            print("[SphereCore] Credentials saved to .env for future sessions.")
        return True
    except Exception as e:
        print(f"[SphereCore] Login failed: {e}")
        return False


# Read credentials live (not cached in module-level globals) so that .env
# edits between process restarts are always picked up.
_startup_email = os.getenv("FIREBASE_EMAIL")
_startup_password = os.getenv("FIREBASE_PASSWORD")

if _startup_email and _startup_password and not _startup_email.startswith("your@"):
    if _try_login(_startup_email, _startup_password, save=False):
        print("[SphereCore] Connected to Firebase.\n")
    else:
        print("[SphereCore] Running in mock mode.\n")
else:
    print("[SphereCore] No saved credentials. Press Enter to use mock mode, or enter your email to log in.")
    email_input = input("Email (or Enter to skip): ").strip()
    if email_input:
        password_input = getpass.getpass("Password: ")
        if _try_login(email_input, password_input, save=True):
            print("[SphereCore] Connected to Firebase.\n")
        else:
            print("[SphereCore] Running in mock mode.\n")
    else:
        print("[SphereCore] Running in mock mode.\n")


def _get_vitals():
    if _firebase_ready:
        try:
            return spherecore.get_vitals()
        except Exception:
            pass
    return mock_vitals()


def _format_reminders(reminders: list) -> str:
    if not reminders:
        return "You don't have any reminders set right now."
    lines = []
    for r in reminders:
        name = r.get("name", "Unknown")
        time_str = r.get("time", "")
        slot = r.get("slot", "")
        days = r.get("days", [])
        note = r.get("note", "")
        day_str = ", ".join(days) if days else "every day"
        line = f"  • {name} at {time_str} ({slot}) — {day_str}"
        if note:
            line += f" [{note}]"
        lines.append(line)
    return "Here are your reminders:\n" + "\n".join(lines)


def _handle_action(action, lang_result):
    if not action:
        return
    intent = action.get("intent")
    if intent == "list_reminders":
        if _firebase_ready:
            try:
                reminders = spherecore.get_reminders()
                print("\n" + _format_reminders(reminders) + "\n")
            except Exception as e:
                print(f"\n[SphereCore] Could not fetch reminders: {e}\n")
        else:
            print("\n[SphereCore] Not connected to Firebase — no reminders available in mock mode.\n")
        return
    if not _firebase_ready:
        return
    if intent == "medication_reminder":
        entities = lang_result.entities
        name = entities.get("medication") or entities.get("medicine") or "Medication"
        time_str = entities.get("time", "08:00")
        slot = _infer_slot(time_str)
        days = entities.get("days") or ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        note = entities.get("note")
        ok = spherecore.add_reminder(name=name, slot=slot, time=time_str, days=days, note=note)
        print("[SphereCore] Reminder saved to Firebase." if ok else "[SphereCore] Failed to save reminder.")


def _infer_slot(time_str: str) -> str:
    try:
        hour = int(time_str.split(":")[0])
        return "morning" if hour < 12 else "afternoon" if hour < 17 else "evening"
    except Exception:
        return "morning"


while True:
    msg = input("You: ").strip()

    if msg.lower() in ("quit", "exit", "q"):
        break
    if not msg:
        continue
    if msg.lower() == "login":
        email_input = input("Email: ").strip()
        password_input = getpass.getpass("Password: ")
        if _try_login(email_input, password_input, save=True):
            print("[SphereCore] Connected to Firebase.\n")
        continue

    try:
        vitals = _get_vitals()
        voice_result = mock_voice()

        lang_result = lang_agent.analyze(msg)
        bio_result = bio_agent.analyze(vitals, source="vital32_live" if _firebase_ready else "mock")

        fused = fusion.fuse(lang_result, bio_result, voice_result)
        emotional_state = emotional_agent.interpret(fused)

        response_result = response_agent.generate(lang_result, emotional_state)

    except Exception as e:
        print(f"\nSphereAI: I'm here — just give me a moment.\n")
        continue

    print()
    print(f"SphereAI: {response_result.reply}")
    print()

    alert_prefix = ""
    if emotional_state.alert_level == "high":
        alert_prefix = " 🔴"
    elif emotional_state.alert_level == "medium":
        alert_prefix = " 🟡"

    print(
        f"[EMOTIONAL STATE] {emotional_state.label}{alert_prefix} | "
        f"arousal={emotional_state.arousal:.2f} | "
        f"valence={emotional_state.valence:.2f} | "
        f"convergence={emotional_state.convergence}/3 | "
        f"confidence={emotional_state.confidence:.0%}"
    )
    print(
        f"[LANGUAGE] intent={lang_result.intent} | "
        f"emotion={lang_result.emotion} | "
        f"confidence={lang_result.confidence:.2f}"
    )

    hr_flag = " ⚠" if bio_result.heart_rate_elevated else ""
    spo2_flag = " ⚠" if bio_result.spo2_low else ""
    print(
        f"[BIOLOGY ({bio_result.source})] "
        f"hr={bio_result.vitals.heart_rate:.0f}{hr_flag} | "
        f"spo2={bio_result.vitals.spo2:.0f}{spo2_flag} | "
        f"stress_flags={bio_result.stress_indicators}"
    )
    print()

    _handle_action(response_result.action, lang_result)
