import argparse
from pathlib import Path

import pandas as pd
import matplotlib.pyplot as plt

parser = argparse.ArgumentParser()
parser.add_argument("session", help="Path to a recording session directory")
args = parser.parse_args()

session = Path(args.session).expanduser().resolve()


def _load_csv(name: str) -> pd.DataFrame | None:
    path = session / name
    if not path.exists():
        print(f"Skipping {name}: file not found")
        return None
    try:
        df = pd.read_csv(path)
    except Exception as exc:
        print(f"Skipping {name}: could not read ({exc})")
        return None
    if df.empty:
        print(f"Skipping {name}: empty file")
        return None
    return df


ecg = _load_csv("ecg.csv")
sensors = _load_csv("sensors.csv")
temperature = _load_csv("temperature.csv")
motor = _load_csv("motor.csv")
ppg = _load_csv("ppg.csv")

fig, axes = plt.subplots(5, 1, figsize=(14, 18))

if ecg is not None:
    axes[0].plot(ecg["timestamp_ms"] / 1000, ecg["ecg_adc"], linewidth=0.7)
    axes[0].set_title("ECG Signal (AD8232)")
    axes[0].set_xlabel("Timestamp (s)")
    axes[0].set_ylabel("ADC Reading")
    axes[0].grid(True, alpha=0.3)
else:
    axes[0].set_title("ECG: no data")
    axes[0].set_visible(True)

if sensors is not None:
    t = sensors["timestamp_ms"] / 1000
    axes[1].plot(t, sensors["ax"], label="ax")
    axes[1].plot(t, sensors["ay"], label="ay")
    axes[1].plot(t, sensors["az"], label="az")
    axes[1].set_title("MPU6050 Accelerometer")
    axes[1].set_xlabel("Timestamp (s)")
    axes[1].set_ylabel("Accel (m/s^2)")
    axes[1].legend()
    axes[1].grid(True, alpha=0.3)
else:
    axes[1].set_title("Accelerometer: no data")

if ppg is not None:
    t_ppg = ppg["timestamp_ms"] / 1000
    axes[2].plot(t_ppg, ppg["red"], label="Red")
    axes[2].plot(t_ppg, ppg["ir"], label="IR")
    axes[2].set_title("MAX30102 PPG")
    axes[2].set_xlabel("Timestamp (s)")
    axes[2].set_ylabel("Raw ADC Counts")
    axes[2].legend()
    axes[2].grid(True, alpha=0.3)
else:
    axes[2].set_title("PPG: no data")

if temperature is not None:
    t_temp = temperature["timestamp_ms"] / 1000
    ax_temp = axes[3]
    ax_temp.plot(t_temp, temperature["temp_c"], color="tab:red", label="temp_c")
    ax_temp.set_xlabel("Timestamp (s)")
    ax_temp.set_ylabel("Temperature (C)", color="tab:red")
    ax_temp.tick_params(axis="y", labelcolor="tab:red")
    ax_temp.set_title("MLX90614 Skin Temperature")
    ax_rate = ax_temp.twinx()
    ax_rate.plot(t_temp, temperature["rate_c_per_hour"], color="tab:blue",
                 linewidth=0.8, linestyle="--", label="rate_c_per_hour")
    ax_rate.set_ylabel("Rate (C/hr)", color="tab:blue")
    ax_rate.tick_params(axis="y", labelcolor="tab:blue")
    lines1, labels1 = ax_temp.get_legend_handles_labels()
    lines2, labels2 = ax_rate.get_legend_handles_labels()
    ax_temp.legend(lines1 + lines2, labels1 + labels2, loc="upper left")
    ax_temp.grid(True, alpha=0.3)
else:
    axes[3].set_title("Temperature: no data")

if motor is not None:
    t_motor = motor["timestamp_ms"] / 1000
    axes[4].plot(t_motor, motor["tremor_band_ratio"], linewidth=0.8, color="tab:purple")
    axes[4].set_title("Parkinson Motor Screen: Tremor Band Ratio")
    axes[4].set_xlabel("Timestamp (s)")
    axes[4].set_ylabel("Tremor Band Ratio")
    axes[4].grid(True, alpha=0.3)
else:
    axes[4].set_title("Motor: no data")

fig.tight_layout()
sensor_plot_path = session / "sensor_plots.png"
fig.savefig(sensor_plot_path, dpi=160)
print(f"Plot saved to: {sensor_plot_path}")
plt.show()
