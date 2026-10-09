
import argparse
from pathlib import Path

import pandas as pd
import matplotlib.pyplot as plt

parser = argparse.ArgumentParser()
parser.add_argument("session", help="Path to a recording session")
args = parser.parse_args()

session = Path(args.session).expanduser().resolve()

ecg = pd.read_csv(session / "ecg.csv")
sensors = pd.read_csv(session / "sensors.csv")
temperature = pd.read_csv(session / "temperature.csv")

fig, axes = plt.subplots(4, 1, figsize=(14, 13))

if not ecg.empty:
    axes[0].plot(
        ecg["timestamp_ms"] / 1000,
        ecg["ecg_raw"],
        linewidth=0.7
    )
    axes[0].set_title("ECG Raw Signal")
    axes[0].set_xlabel("ESP32 Timestamp (seconds)")
    axes[0].set_ylabel("ADC Reading")
else:
    axes[0].set_title("No ECG samples")

if not sensors.empty:
    t = sensors["timestamp_ms"] / 1000
    axes[1].plot(t, sensors["acceleration_x"], label="X")
    axes[1].plot(t, sensors["acceleration_y"], label="Y")
    axes[1].plot(t, sensors["acceleration_z"], label="Z")
    axes[1].set_title("MPU6050 Acceleration")
    axes[1].set_xlabel("ESP32 Timestamp (seconds)")
    axes[1].set_ylabel("Acceleration (m/s²)")
    axes[1].legend()

    axes[2].plot(t, sensors["ir_raw"], label="IR")
    axes[2].plot(t, sensors["red_raw"], label="Red")
    axes[2].set_title("MAX30102 Raw Optical Readings")
    axes[2].set_xlabel("ESP32 Timestamp (seconds)")
    axes[2].set_ylabel("Raw ADC Counts")
    axes[2].legend()

    axes[3].plot(t, sensors["air_temperature_c"], label="Air temperature")
    axes[3].plot(t, sensors["humidity_percent"], label="Humidity")
    axes[3].set_title("Environmental Measurements")
    axes[3].set_xlabel("ESP32 Timestamp (seconds)")
    axes[3].legend()

    for ax in axes[1:]:
        ax.grid(True, alpha=0.3)

fig.tight_layout()
output = session / "sensor_plots.png"
fig.savefig(output, dpi=160)
print(f"Plot saved to: {output}")
plt.show()

if not temperature.empty:
    fig, ax = plt.subplots(figsize=(12, 5))
    t = temperature["timestamp_ms"] / 1000
    ax.plot(t, temperature["ambient_temperature_c"], label="Ambient")
    ax.plot(t, temperature["object_temperature_c"], label="Object")
    ax.set_title("MLX90614 Temperature")
    ax.set_xlabel("ESP32 Timestamp (seconds)")
    ax.set_ylabel("Temperature (°C)")
    ax.legend()
    ax.grid(True, alpha=0.3)
    fig.tight_layout()
    fig.savefig(session / "temperature_plot.png", dpi=160)
    plt.show()