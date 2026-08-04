# LIFESPHERE

**Health · Safety · Automation · Care**

> *An AI-Powered Autonomous Caregiving Ecosystem*

**Research paper:** [`An AI- Powered Autonomous Caregiving Ecosystem.pdf`](./An%20AI-%20Powered%20Autonomous%20Caregiving%20Ecosystem.pdf)
**Live web demo:** <https://spherecore-lite.vercel.app> — the deployed web demo; switch between App Mode and Result Mode in the header
**Android APK:** [app-release.apk](./spherecore/build/app/outputs/apk/release/app-release.apk)

What's built and working right now is SphereCore, in two forms. The Flutter companion app is the primary one, and the web demo in `hollowcore-hardware/web_demo/` is its browser counterpart with two modes: **App Mode** is a web reimplementation of SphereCore's Firebase-backed screens, so it's the same app, not a separate tool — and **Result Mode** is a read-only live mirror of HollowCore's state, updating in real time as control actions land from SphereCore (mobile or App Mode). Everything runs on the one Firebase Realtime Database backend, which is what makes a toggle in one surface show up in the others. LifeSphere as a whole is the larger goal: an autonomous caregiving ecosystem of five subsystems sharing one biological state, monitoring the user across four dimensions (medical, physical, emotional, environmental) and responding without explicit input. The whole point is that the user never has to touch a screen or say a command — the system watches their biology and reacts to that instead. The remaining subsystems are documented and scaffolded but not yet migrated in (see [Project Status](#project-status)).

## Contents

- [Local Development Setup](#local-development-setup)
- [SphereCore](#spherecore)
- [Why LifeSphere?](#why-lifesphere)
- [The Five Subsystems](#the-five-subsystems)
- [System Architecture](#system-architecture)
- [AI Model Pipeline](#ai-model-pipeline)
- [Key Features](#key-features)
- [Bill of Materials](#bill-of-materials)
- [Repository Layout](#repository-layout)
- [Project Status](#project-status)

## Local Development Setup

Here's how to get SphereCore running locally. Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart SDK `^3.10.8` per `pubspec.yaml`).

```bash
git clone https://github.com/fizzcodding/LifeSphereMain.git
cd LifeSphereMain
```

```bash
cd spherecore
flutter pub get
flutter run                      # picks a connected device / emulator
flutter build apk --release      # Android release build
```

Firebase is the backend. The repo ships with `lib/firebase_options.dart` for the `hollow-core` project; to point the app at your own Firebase project, run `flutterfire configure` and set up a Realtime Database following the LifeSphere schema (see Section 7 of the [research PDF](./An%20AI-%20Powered%20Autonomous%20Caregiving%20Ecosystem.pdf)). Note that the camera view (`ControlScreen`) and member management (`MembersScreen`) talk to hardware over the local network — an ESP32-CAM websocket on port 81 and an HTTP endpoint — so those screens won't do anything useful without the physical hardware on the same LAN.

### HollowCore web demo

The web demo runs locally too (Vite + Firebase JS SDK, needs Node.js and npm). It signs in against the same Firebase project as the app, so an account registered on mobile works here directly:

```bash
cd hollowcore-hardware/web_demo
cp .env.example .env     # Firebase web config; values mirror spherecore/lib/firebase_options.dart
npm install
npm run dev              # dev server on http://localhost:5180
```

Once it's up you'll see a mode switch in the header. **App Mode** is a read/write web version of SphereCore's Firebase-backed screens (Devices, Vital32, Reminders, Profile) — writes go to the same database paths the mobile app uses, so toggling a device here drives real hardware. **Result Mode** is a read-only mirror: toggle something from the mobile app and the corresponding tile flashes and logs the change within milliseconds, nothing polled or simulated. More detail (data model, which SphereCore screens are deliberately not reimplemented and why) in [`hollowcore-hardware/web_demo/README.md`](./hollowcore-hardware/web_demo/README.md).

## SphereCore

Since the elderly user is meant to never touch a screen, the app is the window in for guardians and family members instead. It streams the shared biological state object from Firebase Realtime Database into a live dashboard (heart rate, SpO₂, skin temperature, HRV, anomaly score, emotional state, subsystem statuses), manages medication schedules produced by the prescription OCR pipeline before HollowRover starts delivery, and controls HollowCore appliances and ecosystem modes such as Absence Mode. Guardians can add dependent members, define monitoring instructions and receive alerts for falls, intrusions, anomalies, and digital-safety events. The Flutter app builds for Android, iOS, web, and desktop, with Android as the primary target; the web demo's App Mode covers its Firebase-backed screens in the browser.

Full details, screens, and project structure: [`spherecore/README.md`](./spherecore/README.md)

## Why LifeSphere?

Bangladesh has over 15 million elderly citizens, most of whom stay home alone while family members work full-time. Every day people forget critical medication, fall with nobody nearby, and deteriorate physically and emotionally until it turns life-threatening.

**Hypothesis:** an integrated, bioresponsive caregiving ecosystem produces better outcomes than any combination of single-function devices.

Existing smart devices work in silos, a smartwatch tracks heart rate, a smart speaker sets reminders, a camera records video, and none of them talk to each other. LifeSphere ties everything to a single biological state backbone: when Vital32 detects a cortisol spike, SphereAI adjusts its tone, HollowCore changes the lighting, and HollowRover prepares a stress-relief protocol, all automatically.

## The Five Subsystems

| Subsystem | Primary Function | Core Hardware | AI Stack | Repo Directory |
|---|---|---|---|---|
| **Vital32** | Continuous biometric monitoring & home automation trigger | ESP32, MAX30102, MPU6050, MLX90614, BME688, BIA circuit (16-sensor array) | LSTM, Isolation Forest, biological age model | [`vital32/`](./vital32) |
| **HollowRover** | Physical response, medicine delivery, security patrol, passive barrier deterrence | D-Robotics RDK X5 (4GB, 10 TOPS NPU), STL-19P TOF LiDAR, DW1000 UWB, MLX90640 thermal, 6-DOF MG996R arm | SLAM, Nav2, biomarker-triggered protocol engine, DeepFace | [`hollowrover/`](./hollowrover) |
| **SphereAI** | Trimodal emotional intelligence & cognitive monitoring | Microphone, speaker, Whisper STT, OLED via rover | NLP + voice prosody + biomarker fusion classifier | [`sphereai/`](./sphereai) |
| **EntryGuard** | 24/7 intrusion, fire, and gas detection at all entry points | PIR, MQ-2 gas, KY-026 fire, ESP32 nodes | DeepFace recognition, threat classification | [`entryguard/`](./entryguard) |
| **HollowCore** | Biology-responsive home & financial automation | Wi-Fi relay modules, MQTT broker, ESP32 | Biomarker-to-environment mapping, anomaly detection | [`hollowcore-hardware/`](./hollowcore-hardware) |

### Vital32 — The Sensing Layer

A wearable the user forgets they're wearing. Its 16-sensor array captures ECG waveforms, IR skin temperature, accelerometer/gyroscope data (fall and tremor detection), bioelectrical impedance (hydration), galvanic skin response (sympathetic nervous activity), and near-infrared tissue perfusion (wound healing). The onboard AI pipeline is designed to flag immune activation 24–48 hours before symptoms appear and estimate pre-seizure probability 30 minutes before onset.

### HollowRover — The Physical Response Unit

Runs ROS2 Humble on a D-Robotics RDK X5, with SLAM floor mapping and UWB positioning targeting 10 cm accuracy. It executes biomarker-triggered protocols on its own: medication dispensing, fall response dispatch, pre-seizure cushioning, and cortisol-spike deescalation. The 6-DOF arm picks up dropped objects and hands items to the user. As a security deterrent it is passive-barrier only. No contact, no restraint, and any escalation requires human authorization.

### SphereAI — The Emotional Intelligence

A TriAgent architecture: NLP sentiment analysis, vocal prosody extraction, and live Vital32 biomarker feeds, fused by a dynamically weighted meta-classifier. This supports early cognitive decline detection and longitudinal emotional modeling. It also includes an Islamic integration framework: Salah reminders, stress-triggered Adhkar, and a Ramadan mode that restructures medication and hydration around fasting.

### EntryGuard — Perimeter Security

Multi-sensor ESP32 nodes (PIR, ultrasonic, fire, gas) at every entry point, with face recognition checked against registered profiles. It arms itself and only alerts on genuine threats.

### HollowCore — Biology-Responsive Automation

Maps physiological and emotional state directly to lighting, thermal, appliance, and digital safety outputs over Wi-Fi + MQTT. Stressed → lights dim. Cold → AC adjusts. The design also covers financial anomaly detection (Isolation Forest on spending habits) with multi-factor biometric transaction authorization.

## System Architecture

- **Shared Biological State Object** — a continuously updated JSON document on Firebase Realtime Database, the ecosystem's central nervous system. Vital32 writes, everything else subscribes (target latency: 150 ms).
- **Two-channel communication** — cloud-mediated Firebase listeners plus direct MQTT over local Wi-Fi; a 115200-baud serial bridge for sub-10ms motor commands; GSM (SIM800L) fallback during Wi-Fi outages.
- **Multi-timescale inference** — short-cycle (30 s) acute anomaly detection, medium-cycle (15 m) emotional/cortisol models, long-cycle (24 h) biological age clock and circadian modeling.
- **Fault tolerance** — 5000 mAh backup battery, 24 h local SD vital storage, HollowRover doubles as a local hotspot during outages, independent watchdog timers on all five nodes.
- **Security** — TLS in transit, face profiles stored locally (never uploaded), mandatory human authorization before any defensive action, physical-plausibility validation of all sensor readings.

## AI Model Pipeline

| Model | Architecture | Output | Threshold |
|---|---|---|---|
| Anomaly Detector | Isolation Forest (100 trees) | Score 0–1 | 0.7 / 0.9 |
| Pre-Seizure LSTM | 2×LSTM (64, 32) + Dense | Prob 0–1 | 0.85 |
| Emotional Classifier | Weighted 3-stream fusion | State category | Highest |
| Cortisol Estimator | Gradient Boost (200 trees) | ng/dL est. | 15 m update |
| Biological Age Clock | Ensemble (RF + XGBoost) | Age in years | Daily update |
| Cognitive Tracker | Statistical drift (CUSUM) | Deviation score | 2-sigma |

All models are trained offline and run on-device as TensorFlow Lite. They learn the user's own biological baseline over the first 30 days instead of comparing against a generic population.

## Key Features

- **Prescription OCR** — photograph a prescription once; OCR + LLM parsing builds the full medication schedule and syncs it to HollowRover's dispenser, with pressure-sensor adherence logging.
- **Absence Mode** — runs the household while the occupant is away: plant watering, appliance checks, patrols, full-active security, and daily photo/status reports.
- **Remote Guardian** — guardians configure monitoring for dependent family members remotely, including AI-powered digital safety (network-level content filtering, smart screen time, distress-pattern alerts).

## Bill of Materials

| Subsystem | Cost (USD) |
|---|---|
| Vital32 | $67.70 |
| HollowRover | $373.30 |
| SphereAI | $12.00 |
| EntryGuard (×2 nodes) | $36.50 |
| HollowCore | $15.00 |
| **LifeSphere Total** | **$504.50** |

## Repository Layout

```
LifeSphereMain/
├── vital32/                  # ESP32 biosensing wearable (firmware, TFLite models, web demo)
├── hollowrover/              # ROS2 rover workspace, dispenser + ESP32 peripheral sketches
├── sphereai/                 # TriAgent emotional intelligence (Python)
├── entryguard/               # ESP32 perimeter security nodes + face recognition API
├── hollowcore-hardware/      # ESP32 relay firmware, automation logic, web control panel
├── spherecore/               # Flutter companion app (dashboard, reminders, control)
├── MedicineDispenser.FCStd   # FreeCAD model of the medication dispenser
├── ResearchPaper.latex       # Research paper source
└── An AI- Powered Autonomous Caregiving Ecosystem.pdf   # Full build document
```

## Project Status

This is an active competition-stage project, not a finished product. Current state of the code, honestly:

- **Working end to end:** SphereCore in both its forms (Flutter app and the web demo's App Mode / Result Mode), plus the HollowCore ESP32 relay firmware. All of it reads and writes the same Realtime Database, so an appliance toggled in any one surface moves real hardware and shows up in the others.
- **Scaffolded:** the source trees for Vital32, HollowRover, SphereAI, and EntryGuard exist with their intended file layout, but most files are placeholders pending migration of the working code. The hardware builds, sensor integrations, and model designs for these subsystems are documented in the research PDF.
- The performance figures quoted above (150 ms sync latency, 10 cm UWB accuracy, pre-symptom detection windows) are design targets and prototype measurements from the research document, not guarantees of the code in this repo.
- The release APK linked at the top of this page lives under `spherecore/build/`, which is a build-output directory; rebuild with `flutter build apk --release` if it's absent from your checkout.
