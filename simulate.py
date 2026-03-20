import csv
import os
import random
import time
from datetime import datetime
from pathlib import Path

import requests

ROOT_DIR = Path(__file__).resolve().parent
REALTIME_DATA_PATH = ROOT_DIR / "data" / "realtime_data.csv"
PREDICT_URL = os.getenv("SIMULATION_URL", "http://127.0.0.1:8002/predict")
INTERVAL_SECONDS = 5
# Use a specific test UID for simulation to verify targeted notifications
TEST_UID = os.getenv("TEST_UID", "7E9nnDtED5RAOKSLxHr0bUbRzFh1")

FIELDS = [
    "chest_acc_x",
    "chest_acc_x",
    "chest_acc_y",
    "chest_acc_z",
    "wrist_acc_x",
    "wrist_acc_y",
    "wrist_acc_z",
    "heart_rate",
    "body_posture",
]


def ensure_realtime_csv() -> None:
    if REALTIME_DATA_PATH.exists():
        return

    with REALTIME_DATA_PATH.open("w", newline="") as file_handle:
        writer = csv.writer(file_handle)
        writer.writerow(["timestamp", *FIELDS, "risk", "fall_detected"])


def generate_sensor_data() -> dict[str, float | int]:
    return {
        "chest_acc_x": round(random.uniform(-2, 2), 2),
        "chest_acc_y": round(random.uniform(-2, 2), 2),
        "chest_acc_z": round(random.uniform(8, 12), 2),
        "wrist_acc_x": round(random.uniform(-2, 2), 2),
        "wrist_acc_y": round(random.uniform(-2, 2), 2),
        "wrist_acc_z": round(random.uniform(8, 12), 2),
        "heart_rate": random.randint(60, 120),
        "body_posture": random.randint(1, 4),
        "uid": TEST_UID,
    }


def post_prediction(sensor_data: dict[str, float | int | str]) -> tuple[float, bool]:
    response = requests.post(PREDICT_URL, json=sensor_data, timeout=10)
    response.raise_for_status()
    payload = response.json()
    return float(payload["risk"]), bool(payload["fall_detected"])


def append_reading(sensor_data: dict[str, float | int], risk: float, fall_detected: bool) -> None:
    with REALTIME_DATA_PATH.open("a", newline="") as file_handle:
        writer = csv.writer(file_handle)
        writer.writerow([
            datetime.now().isoformat(),
            *(sensor_data[field] for field in FIELDS),
            f"{risk:.4f}",
            int(fall_detected),
        ])


def run_simulation() -> None:
    ensure_realtime_csv()

    while True:
        sensor_data = generate_sensor_data()

        try:
            risk, fall_detected = post_prediction(sensor_data)
            status = "⚠️ HIGH FALL RISK ALERT" if fall_detected else "✅ SAFE"
            print(f"{status} risk={risk:.4f}")
        except requests.RequestException as exc:
            print(f"❌ Could not connect to backend: {exc}")
            risk = 0.0
            fall_detected = False

        append_reading(sensor_data, risk, fall_detected)
        time.sleep(INTERVAL_SECONDS)


if __name__ == "__main__":
    run_simulation()
