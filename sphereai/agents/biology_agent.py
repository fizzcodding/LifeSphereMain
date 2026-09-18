from dataclasses import dataclass


@dataclass
class VitalSigns:
    heart_rate: float
    spo2: float
    skin_temperature: float
    activity: float


@dataclass
class BiologyResult:
    vitals: VitalSigns
    heart_rate_elevated: bool
    spo2_low: bool
    temperature_abnormal: bool
    activity_level: str
    stress_indicators: int
    source: str


def mock_vitals() -> VitalSigns:
    return VitalSigns(
        heart_rate=72.0,
        spo2=98.0,
        skin_temperature=36.6,
        activity=0.25,
    )


class BiologyAgent:
    def analyze(self, vitals: VitalSigns, source: str = "mock") -> BiologyResult:
        heart_rate_elevated = vitals.heart_rate > 100
        spo2_low = vitals.spo2 < 95
        temperature_abnormal = not 36.1 <= vitals.skin_temperature <= 37.5

        if vitals.activity < 0.3:
            activity_level = "resting"
        elif vitals.activity < 0.7:
            activity_level = "light"
        else:
            activity_level = "active"

        stress_indicators = int(heart_rate_elevated) + int(spo2_low) + int(temperature_abnormal)

        return BiologyResult(
            vitals=vitals,
            heart_rate_elevated=heart_rate_elevated,
            spo2_low=spo2_low,
            temperature_abnormal=temperature_abnormal,
            activity_level=activity_level,
            stress_indicators=stress_indicators,
            source=source,
        )
