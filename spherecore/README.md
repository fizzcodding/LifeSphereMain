# SphereCore

> 📱 **Download the app:** the release APK is built to [`build/app/outputs/apk/release/app-release.apk`](build/app/outputs/apk/release/app-release.apk)

**The companion app of the [LifeSphere](../README.md) ecosystem** — *An AI-Powered Autonomous Caregiving Ecosystem.*

SphereCore is the Flutter mobile/web application that puts the entire LifeSphere ecosystem in the palm of the user's (or guardian's) hand. While LifeSphere is designed to be zero-interaction for the elderly user — *technology responding to biology, not the other way around* — SphereCore is the window into the system for guardians, family members, and the users themselves.

## What It Does

- 📊 **Dashboard** — live view of the shared biological state object streamed from Firebase Realtime Database: heart rate, SpO₂, skin temperature, HRV, anomaly score, emotional state, and subsystem statuses (Vital32, HollowRover, SphereAI, EntryGuard, HollowCore).
- 🩺 **Vital32 monitoring** — dedicated screen for the biosensing wearable's real-time metrics and health trends.
- 💊 **Medication reminders** — review and edit schedules extracted by the prescription OCR pipeline, confirm them before HollowRover begins autonomous delivery, and track adherence logs.
- 🎛️ **Control** — HollowCore appliance control (lights, AC/fan, TV, door lock) and ecosystem mode switching (e.g., Absence Mode).
- 👨‍👩‍👧 **Members / Remote Guardian** — guardians add dependent users, define monitoring instructions for SphereAI and HollowCore, and receive alerts (falls, intrusions, anomalies, digital-safety events).
- 📍 **Location & pins** — GPS targets and virtual pins used for location-aware features and UWB-anchored home mapping.
- 🔐 **Auth & profiles** — Firebase Authentication with registered user profiles (also cross-referenced by EntryGuard's face recognition).

## Tech Stack

- **Flutter** (Android / iOS / Web / Linux / macOS / Windows)
- **Firebase** — Auth, Realtime Database (the ecosystem's central nervous system), Storage
- Provider-based state management, local notifications for reminders

## Project Structure

```
lib/
├── main.dart / bootstrap/    # App entry & initialization
├── firebase/                 # Firestore rules & indexes
├── models/                   # Member, medicine, GPS target, virtual pin
├── providers/                # Pin & theme providers
├── screens/
│   ├── auth/                 # Login & registration
│   ├── dashboard/            # Main dashboard, reminders, pins
│   ├── vital32/              # Wearable vitals screen
│   ├── control/              # HollowCore appliance control
│   ├── members/              # Guardian / member management
│   └── profile/              # User profile
├── services/                 # Auth, database, health, reminders,
│                             # notifications, location, members
├── themes/                   # App theming
└── widgets/                  # Shared UI components
```

## Getting Started

1. Install the [Flutter SDK](https://docs.flutter.dev/get-started/install).
2. Configure Firebase for your own project (`flutterfire configure`) — the app expects a Realtime Database following the LifeSphere schema under `/lifesphere/` (see Section 7 of the [research PDF](../An%20AI-%20Powered%20Autonomous%20Caregiving%20Ecosystem.pdf)).
3. Run:

```bash
flutter pub get
flutter run
```

## Part of LifeSphere

SphereCore is one piece of a five-subsystem ecosystem built around a single shared biological state backbone:

**Vital32** (biosensing) · **HollowRover** (physical response) · **SphereAI** (emotional intelligence) · **EntryGuard** (perimeter security) · **HollowCore** (biology-responsive automation)

See the [main README](../README.md) and the full research & build document for the complete architecture.

---

**Team Fälschen** — Faiyaz Bin Iqbal · *"Forged. Wired. Perfected"*
