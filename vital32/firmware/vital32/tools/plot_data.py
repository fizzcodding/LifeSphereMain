#!/usr/bin/env python3
"""Plot Vital32 CSV-style serial records saved by data_logger.py.
Install: python -m pip install pandas matplotlib
Usage: python tools/plot_data.py data/vital32_YYYYMMDD_HHMMSS.csvlog
"""
import argparse
from pathlib import Path
import pandas as pd
import matplotlib.pyplot as plt

p = argparse.ArgumentParser(); p.add_argument('file'); a = p.parse_args()
rows = {k: [] for k in ('E','P','S','T','H')}
for line in Path(a.file).read_text(errors='replace').splitlines():
    parts = line.strip().split(',')
    if parts and parts[0] in rows:
        try: rows[parts[0]].append(parts[1:])
        except Exception: pass

def frame(key, cols):
    good=[]
    for r in rows[key]:
        if len(r) >= len(cols):
            try: good.append([float(x) for x in r[:len(cols)]])
            except ValueError: continue
    return pd.DataFrame(good, columns=cols) if good else pd.DataFrame(columns=cols)

# Each plot is separate so scales remain readable.
plots = [
    ('E', ['ms','ecg_adc','leads_off'], ['ecg_adc'], 'ECG raw ADC'),
    ('P', ['ms','red','ir'], ['red','ir'], 'MAX30102 raw channels'),
    ('S', ['ms','ax_g','ay_g','az_g','gx','gy','gz','air_c','humidity','pressure_hpa','object_c','ambient_c','gas_ohm','steps','gsr_adc','uv_adc','leads_off'], ['ax_g','ay_g','az_g'], 'Acceleration (g)'),
    ('S', ['ms','ax_g','ay_g','az_g','gx','gy','gz','air_c','humidity','pressure_hpa','object_c','ambient_c','gas_ohm','steps','gsr_adc','uv_adc','leads_off'], ['object_c','air_c','ambient_c'], 'Temperature (°C)'),
    ('S', ['ms','ax_g','ay_g','az_g','gx','gy','gz','air_c','humidity','pressure_hpa','object_c','ambient_c','gas_ohm','steps','gsr_adc','uv_adc','leads_off'], ['steps'], 'Step counter'),
    ('T', ['ms','object_c','rate_c_per_hour','cusum','baseline_ready','alert'], ['rate_c_per_hour','cusum'], 'Temperature trend'),
    ('H', ['ms','valid','rmssd_ms','sdnn_ms'], ['rmssd_ms','sdnn_ms'], 'HRV estimates (ms)'),
]
made=0
for key, cols, ys, title in plots:
    df=frame(key, cols)
    if df.empty: continue
    x=(df['ms']-df['ms'].iloc[0])/1000.0
    plt.figure();
    for y in ys:
        if y in df: plt.plot(x, df[y], label=y)
    plt.xlabel('Elapsed time (s)'); plt.ylabel(title); plt.title(title)
    if len(ys)>1: plt.legend()
    plt.grid(True); plt.tight_layout(); made+=1
if not made: print('No plottable E/P/S/T/H records found. Set HUMAN_READABLE_SERIAL to 0 and record the serial stream.')
else: plt.show()
