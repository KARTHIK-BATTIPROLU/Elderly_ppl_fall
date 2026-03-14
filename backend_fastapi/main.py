import csv
import os
import random
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Any

import firebase_admin
import google.auth
import joblib
import pandas as pd
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from firebase_admin import credentials, firestore, messaging
from google.auth.exceptions import DefaultCredentialsError
from pydantic import BaseModel, Field

ROOT_DIR = Path(__file__).resolve().parents[1]
MODEL_PATH = ROOT_DIR / "model" / "rf_model.pkl"
REALTIME_DATA_PATH = ROOT_DIR / "data" / "realtime_data.csv"
SERVICE_ACCOUNT_KEY_PATH = Path(
    os.getenv("FIREBASE_SERVICE_ACCOUNT_KEY_PATH", ROOT_DIR / "serviceAccountKey.json")
)
FIREBASE_PROJECT_ID = os.getenv("FIREBASE_PROJECT_ID", "fall-prevention-sys-26")

FEATURES_ORDER = [
    "chest_acc_x",
    "chest_acc_y",
    "chest_acc_z",
    "wrist_acc_x",
    "wrist_acc_y",
    "wrist_acc_z",
    "heart_rate",
    "body_posture",
]

RISK_THRESHOLD = float(os.getenv("RISK_THRESHOLD", "0.40"))


def initialize_firebase_admin() -> None:
    if firebase_admin._apps:
        return

    app_options = {"projectId": FIREBASE_PROJECT_ID}

    if SERVICE_ACCOUNT_KEY_PATH.exists():
        firebase_admin.initialize_app(
            credentials.Certificate(str(SERVICE_ACCOUNT_KEY_PATH)),
            options=app_options,
        )
        print(f"Initialized Firebase Admin with service account: {SERVICE_ACCOUNT_KEY_PATH}")
        return

    try:
        google.auth.default()
        firebase_admin.initialize_app(credentials.ApplicationDefault(), options=app_options)
        print("Initialized Firebase Admin with application default credentials")
    except DefaultCredentialsError:
        firebase_admin.initialize_app(options=app_options)
        print("Initialized Firebase Admin with project ID only")


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.model = joblib.load(MODEL_PATH)
    initialize_firebase_admin()
    yield


class PredictRequest(BaseModel):
    chest_acc_x: float = Field(..., description="Chest accelerometer X")
    chest_acc_y: float = Field(..., description="Chest accelerometer Y")
    chest_acc_z: float = Field(..., description="Chest accelerometer Z")
    wrist_acc_x: float = Field(..., description="Wrist accelerometer X")
    wrist_acc_y: float = Field(..., description="Wrist accelerometer Y")
    wrist_acc_z: float = Field(..., description="Wrist accelerometer Z")
    heart_rate: int = Field(..., ge=0, description="Heart rate in BPM")
    body_posture: int = Field(..., ge=0, le=4, description="Encoded posture class")


class PredictResponse(BaseModel):
    risk: float
    risk_score: float
    fall_detected: bool


app = FastAPI(
    title="Fall Risk Prediction API",
    version="1.0.0",
    description="FastAPI backend for ML-driven elder fall risk prediction.",
    lifespan=lifespan,
)

_allowed_origins = os.getenv("CORS_ALLOW_ORIGINS", "*")
allowed_origins = [o.strip() for o in _allowed_origins.split(",") if o.strip()]
allow_all_origins = allowed_origins == ["*"]
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
def root() -> dict[str, str]:
    return {
        "service": "fastapi-fall-risk",
        "status": "ok",
        "docs": "/docs",
        "health": "/health",
    }


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "backend running"}


@app.get("/random-data")
def random_data() -> dict[str, Any]:
    try:
        return load_random_sample()
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Unable to load sample data: {exc}")


@app.post("/predict", response_model=PredictResponse)
def predict(
    payload: PredictRequest,
):
    print("Prediction request received")
    feature_map = payload.model_dump()
    features_df = pd.DataFrame([feature_map], columns=FEATURES_ORDER)

    probability = float(app.state.model.predict_proba(features_df)[0][1])
    fall_detected = probability >= RISK_THRESHOLD

    if fall_detected:
        send_high_risk_push_to_all(feature_map, probability)

    return PredictResponse(
        risk=round(probability, 4),
        risk_score=round(probability, 4),
        fall_detected=fall_detected,
    )


def load_random_sample() -> dict[str, Any]:
    rows: list[dict[str, Any]] = []

    with REALTIME_DATA_PATH.open(newline="") as file_handle:
        reader = csv.reader(file_handle)
        for raw_row in reader:
            if len(raw_row) < 9:
                continue

            # Skip duplicate header rows and malformed merged rows.
            if raw_row[0] == "timestamp" or raw_row[1] == "chest_acc_x":
                continue

            try:
                rows.append(
                    {
                        "chest_acc_x": float(raw_row[1]),
                        "chest_acc_y": float(raw_row[2]),
                        "chest_acc_z": float(raw_row[3]),
                        "wrist_acc_x": float(raw_row[4]),
                        "wrist_acc_y": float(raw_row[5]),
                        "wrist_acc_z": float(raw_row[6]),
                        "heart_rate": int(float(raw_row[7])),
                        "body_posture": int(float(raw_row[8])),
                    }
                )
            except (TypeError, ValueError):
                continue

    if not rows:
        raise ValueError("No valid sensor samples available")

    return random.choice(rows)


def send_high_risk_push_to_all(feature_map: dict[str, float | int], probability: float) -> None:
    try:
        db = firestore.client()
        docs = db.collection("users").stream()
        tokens: list[str] = []
        for doc in docs:
            token = (doc.to_dict() or {}).get("device_token")
            if isinstance(token, str) and token.strip():
                tokens.append(token.strip())

        if not tokens:
            print("No device tokens available for high-risk notification")
            return

        for token in set(tokens):
            message = messaging.Message(
                notification=messaging.Notification(
                    title="Fall Detected",
                    body="High fall risk detected",
                ),
                data={
                    "type": "fall_risk",
                    "risk": f"{probability:.4f}",
                    "heart_rate": str(feature_map.get("heart_rate", "")),
                    "body_posture": str(feature_map.get("body_posture", "")),
                },
                token=token,
                android=messaging.AndroidConfig(
                    priority="high",
                    notification=messaging.AndroidNotification(channel_id="fall_risk_alerts"),
                ),
            )
            messaging.send(message)
    except Exception as exc:
        print(f"FCM dispatch error: {exc}")
