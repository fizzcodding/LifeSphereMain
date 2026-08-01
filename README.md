# LIFESPHERE

**Health · Safety · Automation · Care**

*An AI-Powered Autonomous Caregiving Ecosystem*
**Team Fälschen** — Lead Researcher: Faiyaz Bin Iqbal
*"Forged. Wired. Perfected"*

LifeSphere is five subsystems running off one shared biological state. Instead of five separate gadgets that each do their own thing, everything reads and writes to the same live picture of the user's medical, physical, emotional, and environmental status — and reacts to it without anyone touching a phone.

Full technical writeup and build documentation: [`An AI- Powered Autonomous Caregiving Ecosystem.pdf`](./An%20AI-%20Powered%20Autonomous%20Caregiving%20Ecosystem.pdf)

---

## Why I built this

Bangladesh has over 15 million elderly citizens, and most of them are home alone all day while their families work. That's the actual starting point for this project — not a hypothetical user persona, an observation about how care actually breaks down here. Missed medication, falls with nobody around to notice, slow emotional decline that nobody catches until it's a crisis. All of that is preventable if something is actually watching, continuously, without needing the person to remember to check in with a device.

Most smart health devices work in isolation — a watch tracks heart rate, a speaker sets reminders, a camera records footage, and none of them talk to each other. LifeSphere's whole premise is that tying these into one shared state produces better outcomes than any of them running solo. If Vital32 picks up a cortisol spike, SphereAI shifts its tone, HollowCore dims the lighting, and HollowRover is already staging a de-escalation routine — automatically, same tick.

---

## The Five Subsystems

| Subsystem | Primary Function | Core Hardware | AI Stack | Repo Directory |
|---|---|---|---|---|
| **Vital32** | Continuous biometric monitoring & home automation trigger | ESP32, MAX30102, MPU6050, MLX90614, BME688, BIA circuit (16-sensor array) | LSTM, Isolation Forest, biological age model | [`vital32/`](./vital32) |
| **HollowRover** | Physical response, medicine delivery, security patrol, passive barrier deterrence | D-Robotics RDK X5 (4GB, 10 TOPS NPU), STL-19P TOF LiDAR, DW1000 UWB, MLX90640 thermal, 6-DOF MG996R arm | SLAM, Nav2, biomarker-triggered protocol engine, DeepFace | [`hollowrover/`](./hollowrover) |
| **SphereAI** | Trimodal emotional intelligence & cognitive monitoring | Microphone, speaker, Whisper STT, OLED via rover | NLP + voice prosody + biomarker fusion classifier | [`sphereai/`](./sphereai) |
| **EntryGuard** | 24/7 intrusion, fire, and gas detection at all entry points | PIR, MQ-2 gas, KY-026 fire, ESP32 nodes | DeepFace recognition, threat classification | [`entryguard/`](./entryguard) |
| **HollowCore** | Biology-responsive home & financial automation | Wi-Fi relay modules, MQTT broker, ESP32 | Biomarker-to-environment mapping, anomaly detection | [`hollowcore-hardware/`](./hollowcore-hardware) |

Companion mobile/web app: [`spherecore/`](./spherecore) (Flutter).

### Vital32 — the sensing layer
This is the wearable, and the goal was to make it something you forget you're wearing. Sixteen sensors on one board: ECG, IR skin temp, accel/gyro for fall and tremor detection, bioelectrical impedance for hydration, GSR for sympathetic nervous activity, and near-infrared for tissue perfusion. The onboard pipeline is trained to catch immune activation and pre-seizure signatures before symptoms show — those detection windows are from my model's training/validation runs on the sensor data, documented in the full build PDF, not a clinical claim.

### HollowRover — the physical response unit
Runs ROS2 Humble on a D-Robotics RDK X5. SLAM for floor mapping, UWB for positioning down to about 10cm. It handles medication dispensing, fall response, pre-seizure cushioning, and cortisol de-escalation on its own — no human has to trigger any of it. The 6-DOF arm can pick up dropped objects and hand things to the user. On the security side it's strictly passive-barrier: it can block, it does not restrain, and anything beyond that needs a human to authorize it. I was deliberate about that line — I didn't want to build something that could physically restrain a person, full stop.

### SphereAI — the emotional intelligence layer
Three-stream fusion: NLP sentiment, vocal prosody, and live Vital32 biomarkers, combined through a dynamically weighted meta-classifier. This is what's doing early cognitive decline detection and tracking emotional patterns over time. It also has an Islamic integration layer built in — Salah reminders, stress-triggered Adhkar, and a Ramadan mode that restructures the medication and hydration schedule around the fast. This part wasn't an afterthought; it's built for how the actual target users live.

### EntryGuard — perimeter security
ESP32 nodes at every entry point running PIR, ultrasonic, fire, and gas sensing, plus face recognition against registered profiles. Arms itself, only alerts on things that are actually a threat instead of every motion trigger.

### HollowCore — biology-responsive automation
Maps the current physiological/emotional state straight to lighting, thermal control, appliances, and digital safety settings over MQTT. Stressed → lights come down. Cold → AC adjusts. It also runs an Isolation Forest over spending patterns for financial anomaly detection, with biometric multi-factor auth on flagged transactions.

---

## System Architecture

- **Shared Biological State Object** — one continuously updated JSON document on Firebase Realtime Database. Vital32 writes to it, every other subsystem subscribes. Target latency is 150ms end to end.
- **Two-channel comms** — Firebase listeners over cloud for the main state sync, direct MQTT over local Wi-Fi as the fast path, a 115200-baud serial bridge for sub-10ms motor commands, and SIM800L GSM as fallback when Wi-Fi drops.
- **Multi-timescale inference** — short-cycle (30s) for acute anomalies, medium-cycle (15min) for emotional/cortisol modeling, long-cycle (24h) for the biological age clock and circadian tracking.
- **Fault tolerance** — 5000mAh backup battery, 24h of local SD vital storage, HollowRover can act as a local hotspot during an outage, independent watchdog timers on all five nodes.
- **Security** — TLS in transit, face profiles stay local and never get uploaded anywhere, human authorization required before any defensive action, and sensor readings get checked for physical plausibility before they're trusted.

## AI Model Pipeline

| Model | Architecture | Output | Threshold |
|---|---|---|---|
| Anomaly Detector | Isolation Forest (100 trees) | Score 0–1 | 0.7 / 0.9 |
| Pre-Seizure LSTM | 2×LSTM (64, 32) + Dense | Prob 0–1 | 0.85 |
| Emotional Classifier | Weighted 3-stream fusion | State category | Highest |
| Cortisol Estimator | Gradient Boost (200 trees) | ng/dL est. | 15 m update |
| Biological Age Clock | Ensemble (RF + XGBoost) | Age in years | Daily update |
| Cognitive Tracker | Statistical drift (CUSUM) | Deviation score | 2-sigma |

All models train offline and run on-device as TFLite. None of them ship with a generic population baseline — each one calibrates against the specific user's own data over the first 30 days, because "normal" vitals vary enough person to person that a population average isn't that useful for anomaly detection at the individual level.

## Key Features

- **Prescription OCR** — photograph a prescription once, OCR + LLM parsing extracts the schedule and syncs it directly to HollowRover's dispenser. Pressure sensors in the dispenser log actual adherence, not just whether a reminder fired.
- **Absence Mode** — runs the household while nobody's home: waters plants, checks appliances, patrols, goes full-active on security, sends daily status photos.
- **Remote Guardian** — family members can configure monitoring for a dependent relative remotely, including content filtering, screen time limits, and distress-pattern alerts.

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

Built the entire technical scope solo: subsystem architecture, biosensor integration, the trimodal LLM pipeline, ML model training, ROS2 robotics and kinematics, PCB design, computer vision, the Firebase real-time backend, and the autonomous medication dispenser mechanism and control logic.

---

Elderly isolation and inadequate home care are things I've seen play out in real households here, not an abstract problem statement. LifeSphere is my attempt at doing something about it — connecting what's actually happening in someone's body to something that can physically respond, before it turns into an emergency.
