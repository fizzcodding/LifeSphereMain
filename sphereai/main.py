import os
import getpass
from agents.language_agent import LanguageAgent
from agents.biology_agent import BiologyAgent, mock_vitals
from agents.voice_agent import VoiceAgent, mock_voice
from agents.response_agent import ResponseAgent
from agents.emotional_agent import EmotionalAgent
from fusion.emotional_fusion import EmotionalFusion
from core.spherecore_client import SphereCoreClient
from core.gemini import transcribe
from core.speech import speak
from core.crisis import is_crisis, crisis_response
from core.reminder_utils import infer_slot, validate_reminder

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
voice_agent.warmup()
emotional_agent = EmotionalAgent()
fusion = EmotionalFusion()
response_agent = ResponseAgent()
spherecore = SphereCoreClient()

_firebase_ready = False


def _try_login(email: str, password: str) -> bool:
    global _firebase_ready
    try:
        spherecore.authenticate(email, password)
        _firebase_ready = True
        return True
    except Exception as e:
        print(f'[SphereCore] Login failed: {e}')
        return False


_startup_email = os.getenv('FIREBASE_EMAIL')
_startup_password = os.getenv('FIREBASE_PASSWORD')

if _startup_email and _startup_password and not _startup_email.startswith('your@'):
    if _try_login(_startup_email, _startup_password):
        print('[SphereCore] Connected to Firebase.\n')
    else:
        print('[SphereCore] Running in mock mode.\n')
else:
    print('[SphereCore] No saved credentials. Press Enter to use mock mode, or enter your email to log in.')
    email_input = input('Email (or Enter to skip): ').strip()
    if email_input:
        password_input = getpass.getpass('Password: ')
        if _try_login(email_input, password_input):
            print('[SphereCore] Connected to Firebase.\n')
        else:
            print('[SphereCore] Running in mock mode.\n')
    else:
        print('[SphereCore] Running in mock mode.\n')


def _get_vitals():
    if _firebase_ready:
        try:
            v = spherecore.get_vitals()
            if v is not None:
                return v, 'vital32_live'
        except Exception:
            pass
    return mock_vitals(), 'mock'


def _format_reminders(reminders: list) -> str:
    if not reminders:
        return 'You do not have any reminders set right now.'
    lines = []
    for r in reminders:
        name = r.get('name', 'Unknown')
        time_str = r.get('time', '')
        slot = r.get('slot', '')
        days = r.get('days', [])
        note = r.get('note', '')
        day_str = ', '.join(days) if days else 'every day'
        line = f'  {name} at {time_str} ({slot}) - {day_str}'
        if note:
            line += f' [{note}]'
        lines.append(line)
    return 'Here are your reminders:\n' + '\n'.join(lines)


def _handle_action(action, lang_result):
    if not action:
        return
    intent = action.get('intent')
    if intent == 'list_reminders':
        if _firebase_ready:
            try:
                reminders = spherecore.get_reminders()
                print('\n' + _format_reminders(reminders) + '\n')
            except Exception as e:
                print(f'\n[SphereCore] Could not fetch reminders: {e}\n')
        else:
            print('\n[SphereCore] Not connected to Firebase - no reminders available in mock mode.\n')
        return
    if not _firebase_ready:
        return
    if intent == 'medication_reminder':
        entities = lang_result.entities
        name = entities.get('medication') or entities.get('medicine') or 'Medication'
        time_str = entities.get('time', '08:00')
        slot = infer_slot(time_str)
        days = entities.get('days') or [
            'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
        ]
        note = entities.get('note')
        ok_val, err = validate_reminder(name, slot, time_str, days, note)
        if not ok_val:
            print(f'[SphereCore] Reminder validation failed: {err}')
            return
        ok = spherecore.add_reminder(name=name, slot=slot, time=time_str, days=days, note=note)
        print('[SphereCore] Reminder saved to Firebase.' if ok else '[SphereCore] Failed to save reminder.')


emergency_num = os.getenv('CRISIS_EMERGENCY_NUMBER', '999')

while True:
    msg = input('You: ').strip()
    voice_result = None

    if msg.lower() in ('quit', 'exit', 'q'):
        break
    if not msg:
        continue
    if msg.lower() == 'login':
        email_input = input('Email: ').strip()
        password_input = getpass.getpass('Password: ')
        if _try_login(email_input, password_input):
            print('[SphereCore] Connected to Firebase.\n')
        continue

    if msg.lower() in ('v', 'voice', 'p', 'ptt'):
        try:
            if msg.lower() in ('p', 'ptt'):
                from core.esp_audio import get_esp, use_esp

                if not use_esp():
                    print('Push to talk needs SPHEREAI_AUDIO=esp.\n')
                    continue
                print('Press the BOOT button on the ESP32-S3 to talk...')
                if not get_esp().wait_button(timeout=60):
                    print('No button press.\n')
                    continue
            print('Listening for 6 seconds...')
            y = voice_agent.listen(6.0)
            msg = transcribe(voice_agent.to_wav_bytes(y)).strip()
            voice_result = voice_agent.analyze_signal(y)
        except Exception as e:
            print(f'[Voice] failed: {e}\n')
            continue
        if not msg:
            print('Didn\'t catch anything.\n')
            continue
        print(f'You (voice): {msg}')

    try:
        vitals, bio_source = _get_vitals()
        if voice_result is None:
            voice_result = mock_voice()

        lang_result = lang_agent.analyze(msg)
        bio_result = bio_agent.analyze(vitals, source=bio_source)

        fused = fusion.fuse(lang_result, bio_result, voice_result)
        emotional_state = emotional_agent.interpret(fused)

        response_result = response_agent.generate(lang_result, emotional_state)

    except Exception as e:
        print(f'\nSphereAI: I\'m here - just give me a moment.\n')
        continue

    if is_crisis(msg, lang_result.emotion):
        crisis_reply = crisis_response(emergency_num)
        print()
        print(f'SphereAI: {crisis_reply}')
        speak(crisis_reply)
        emotional_state.alert_level = 'high'
        if _firebase_ready:
            try:
                spherecore.write_alert('high', 'crisis', 'Self-harm or suicidal language detected')
            except Exception:
                pass
        print()
        continue

    print()
    print(f'SphereAI: {response_result.reply}')
    speak(response_result.reply)
    print()

    if emotional_state.alert_level == 'high' and _firebase_ready:
        try:
            spherecore.write_alert(
                'high',
                emotional_state.label,
                f'Alert from SphereAI: {emotional_state.label}',
            )
        except Exception:
            pass

    alert_prefix = ''
    if emotional_state.alert_level == 'high':
        alert_prefix = ' [HIGH]'
    elif emotional_state.alert_level == 'medium':
        alert_prefix = ' [MED]'

    print(
        f'[EMOTIONAL STATE] {emotional_state.label}{alert_prefix} | '
        f'arousal={emotional_state.arousal:.2f} | '
        f'valence={emotional_state.valence:.2f} | '
        f'convergence={emotional_state.convergence}/3 | '
        f'confidence={emotional_state.confidence:.0%}'
    )
    print(
        f'[LANGUAGE] intent={lang_result.intent} | '
        f'emotion={lang_result.emotion} | '
        f'confidence={lang_result.confidence:.2f}'
    )

    hr_val = f'{bio_result.vitals.heart_rate:.0f}' if bio_result.vitals.heart_rate is not None else 'N/A'
    spo2_val = f'{bio_result.vitals.spo2:.0f}' if bio_result.vitals.spo2 is not None else 'N/A'
    hr_flag = ' [!]' if bio_result.heart_rate_elevated else ''
    spo2_flag = ' [!]' if bio_result.spo2_low else ''
    print(
        f'[BIOLOGY ({bio_result.source})] '
        f'hr={hr_val}{hr_flag} | '
        f'spo2={spo2_val}{spo2_flag} | '
        f'stress_flags={bio_result.stress_indicators}'
    )
    print(
        f'[VOICE ({voice_result.source})] '
        f'pitch={voice_result.pitch_mean:.0f} | '
        f'energy={voice_result.energy:.2f} | '
        f'rate={voice_result.speaking_rate:.1f} | '
        f'tremor={voice_result.tremor} | '
        f'pauses={voice_result.long_pauses}'
    )
    print()

    _handle_action(response_result.action, lang_result)
