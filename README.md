# LIFESPHERE

**Health · Safety · Automation · Care**

> *An AI-Powered Autonomous Caregiving Ecosystem*
> **Team Fälschen** — Lead Researcher: Faiyaz Bin Iqbal
> *"Forged. Wired. Perfected"*

LifeSphere is a fully integrated, AI-powered autonomous caregiving ecosystem comprising **five interconnected subsystems** that function as a single synchronized intelligence — monitoring, predicting, and responding to the user across four simultaneous dimensions: **medical, physical, emotional, and environmental** — without requiring continuous human supervision or explicit user input.

> **LifeSphere does not require the user to interact with technology. It requires technology to respond to the user's biology.**

📄 The complete technical research and build document is included in this repo: [`An AI- Powered Autonomous Caregiving Ecosystem.pdf`](./An%20AI-%20Powered%20Autonomous%20Caregiving%20Ecosystem.pdf)

---

## Why LifeSphere?

Bangladesh is home to over **15 million elderly citizens**, most of whom remain at home while family members work full-time. Every day, thousands forget critical medication, sustain falls with no one nearby to respond, and experience silent physical and emotional deterioration that goes undetected until it becomes life-threatening.

**Hypothesis:** A fully integrated, bioresponsive caregiving ecosystem provides superior caregiving outcomes compared to any combination of existing single-function devices.

Traditional smart devices operate in silos — a smartwatch tracks heart rate, a smart speaker sets reminders, a security camera records video. LifeSphere unifies these into a **single biological state backbone**: when Vital32 detects a cortisol spike, SphereAI adjusts its tone, HollowCore alters the lighting, and HollowRover prepares a stress-relief protocol — all automatically.

---

## The Five Subsystems

| Subsystem | Primary Function | Core Hardware | AI Stack | Repo Directory |
|---|---|---|---|---|
| **Vital32** | Continuous biometric monitoring & home automation trigger | ESP32, MAX30102, MPU6050, MLX90614, BME688, BIA circuit (16-sensor array) | LSTM, Isolation Forest, biological age model | [`vital32/`](./vital32) |
| **HollowRover** | Physical response, medicine delivery, security patrol, passive barrier deterrence | D-Robotics RDK X5 (4GB, 10 TOPS NPU), STL-19P TOF LiDAR, DW1000 UWB, MLX90640 thermal, 6-DOF MG996R arm | SLAM, Nav2, biomarker-triggered protocol engine, DeepFace | [`hollowrover/`](./hollowrover) |
| **SphereAI** | Trimodal emotional intelligence & cognitive monitoring | Microphone, speaker, Whisper STT, OLED via rover | NLP + voice prosody + biomarker fusion classifier | [`sphereai/`](./sphereai) |
| **EntryGuard** | 24/7 intrusion, fire, and gas detection at all entry points | PIR, MQ-2 gas, KY-026 fire, ESP32 nodes | DeepFace recognition, threat classification | [`entryguard/`](./entryguard) |
| **HollowCore** | Biology-responsive home & financial automation | Wi-Fi relay modules, MQTT broker, ESP32 | Biomarker-to-environment mapping, anomaly detection | [`hollowcore-hardware/`](./hollowcore-hardware) |

The companion mobile/web app lives in [`spherecore/`](./spherecore) (Flutter).

### 🩺 Vital32 — The Sensing Layer
Worn by the user, operating invisibly. A 16-sensor array acquires ECG waveforms, IR skin temperature, accelerometer/gyroscope data (fall + tremor detection), bioelectrical impedance (hydration), galvanic skin response (sympathetic nervous activity), and near-infrared tissue perfusion (wound healing). Its onboard AI pipeline enables **immune activation detection 24–48 hours before symptom onset** and **pre-seizure probability estimation 30 minutes before onset**.

### 🤖 HollowRover — The Physical Response Unit
Runs ROS2 Humble on a D-Robotics RDK X5 with SLAM floor mapping and UWB positioning accurate to **within 10 cm**. Executes biomarker-triggered protocols autonomously: medication dispensing, fall response dispatch, pre-seizure cushioning, and cortisol-spike deescalation. Its 6-DOF robotic arm retrieves dropped objects, hands items to the user, and serves as a **passive-barrier-only** security deterrent (no contact, no restraint — human authorization required for any escalation).

### 💬 SphereAI — The Emotional Intelligence
A **TriAgent architecture**: NLP sentiment analysis + vocal prosody extraction + live Vital32 biomarker feeds, fused by a dynamically weighted meta-classifier. Enables early cognitive decline detection and longitudinal emotional modeling. Includes an Islamic integration framework — Salah reminders, stress-triggered Adhkar, and a Ramadan mode restructuring medication/hydration around fasting.

### 🚪 EntryGuard — Perimeter Security
Multi-sensor ESP32 nodes (PIR, ultrasonic, fire, gas) at all entry points with face recognition cross-referenced against registered profiles. Arms automatically; alerts only on genuine threats.

### 🏠 HollowCore — Biology-Responsive Automation
Maps physiological and emotional state directly to lighting, thermal, appliance, and digital safety outputs via Wi-Fi + MQTT. Stressed → lights dim. Cold → AC adjusts. Also provides **financial anomaly detection** (Isolation Forest on spending habits) with multi-factor biometric transaction authorization.

---

## System Architecture

- **Shared Biological State Object** — a continuously updated JSON document on Firebase Realtime Database serving as the ecosystem's central nervous system; Vital32 writes, all subsystems subscribe (target latency: **150 ms**).
- **Two-channel communication** — cloud-mediated Firebase listeners + direct MQTT over local Wi-Fi; a 115200-baud serial bridge for sub-10ms motor commands; GSM (SIM800L) fallback during Wi-Fi outages.
- **Multi-timescale inference** — short-cycle (30 s) acute anomaly detection, medium-cycle (15 m) emotional/cortisol models, long-cycle (24 h) biological age clock & circadian modeling.
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

All models are trained offline and deployed as TensorFlow Lite on-device. Models learn the **user's own biological baseline** (first 30 days) rather than comparing against a generic population.

## Key Features

- 💊 **Prescription OCR** — photograph a prescription once; OCR + LLM parsing auto-builds the full medication schedule, synced to HollowRover's dispenser with pressure-sensor adherence logging.
- 🏡 **Absence Mode** — autonomous household management while the occupant is away: plant watering, appliance checks, patrols, full-active security, and daily photo/status reports.
- 👨‍👧 **Remote Guardian** — guardians configure monitoring for dependent family members remotely, including AI-powered digital safety (network-level content filtering, smart screen time, distress-pattern alerts).

## Bill of Materials

| Subsystem | Cost (USD) |
|---|---|
| Vital32 | $67.70 |
| HollowRover | $373.30 |
| SphereAI | $12.00 |
| EntryGuard (×2 nodes) | $36.50 |
| HollowCore | $15.00 |
| **LifeSphere Total** | **$504.50** |

A complete caregiving ecosystem for roughly the price of a mid-range smartphone.

## Repository Layout

```
LifeSphereMain/
├── vital32/                  # ESP32 biosensing wearable firmware
├── hollowrover/              # ROS2 autonomous rover (SLAM, Nav2, arm control)
├── sphereai/                 # TriAgent emotional intelligence (Python)
├── entryguard/               # ESP32 perimeter security node firmware
├── hollowcore-hardware/      # Biology-responsive automation (ESP32 + MQTT)
├── spherecore/               # Flutter companion app (dashboard, reminders, control)
├── MedicineDispenser.FCStd   # FreeCAD model of the medication dispenser
├── ResearchPaper.latex       # Research paper source
└── An AI- Powered Autonomous Caregiving Ecosystem.pdf   # Full build document
```

## Team Fälschen

**Faiyaz Bin Iqbal** — Lead Researcher & Sole Engineer
Birshreshtha Munshi Abdur Rouf Public College

Independently executed the entire technical scope: subsystem architecture, biosensor integration, trimodal LLM pipeline, ML model training, ROS2 robotics + kinematics, PCB design, computer vision, Firebase real-time backend, and the autonomous medication dispensing system.

---

*LifeSphere addresses the global crisis of elderly isolation and inadequate care. By autonomously bridging the gap between biological signals and physical intervention, it preserves human dignity, prevents preventable fatalities, and ensures the most vulnerable members of society are never truly alone.*
