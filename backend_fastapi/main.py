import csv
import os
import random
import time
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
FIREBASE_PROJECT_ID = os.getenv("FIREBASE_PROJECT_ID", "fall-prevention-sys-26")


def _resolve_service_account_key_path() -> Path:
    configured_path = os.getenv("FIREBASE_SERVICE_ACCOUNT_KEY_PATH")
    if configured_path:
        return Path(configured_path)

    candidates = [
        ROOT_DIR / "serviceAccountKey.json",
        ROOT_DIR / "serviceAccountKey.json.json",
    ]
    for candidate in candidates:
        if candidate.exists():
            return candidate

    return candidates[0]


SERVICE_ACCOUNT_KEY_PATH = _resolve_service_account_key_path()

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
NOTIFICATION_COOLDOWN_SECONDS = int(
    os.getenv("NOTIFICATION_COOLDOWN_SECONDS", "30")
)

# Global cooldown guard per user
_last_push_sent_at: dict[str, float] = {}


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
        print(
            "WARNING: Firebase Admin initialized WITHOUT credentials. "
            "FCM push notifications will NOT work.\n"
            "  Fix: download serviceAccountKey.json from Firebase Console → "
            "Project Settings → Service Accounts → Generate new private key, "
            "then place it in the project root."
        )


@asynccontextmanager
async def lifespan(app: FastAPI):
    if not MODEL_PATH.exists():
        raise FileNotFoundError(f"Model file not found at: {MODEL_PATH}")
    print(f"Loading model from: {MODEL_PATH}")
    app.state.model = joblib.load(MODEL_PATH)
    print("Model loaded successfully")

    if not REALTIME_DATA_PATH.exists():
        print(f"WARNING: Realtime data file not found at: {REALTIME_DATA_PATH}")

    initialize_firebase_admin()
    print("Backend startup complete")
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
    uid: str | None = Field(None, description="User ID for targeted notification")


class PredictResponse(BaseModel):
    risk: float
    risk_score: float
    fall_detected: bool
    notification_attempted: bool = False
    notification_sent_count: int = 0
    notification_target_count: int = 0


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
    allow_credentials=False,
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
    print(f"Prediction request received. UID={payload.uid}")
    feature_map = payload.model_dump()
    features_df = pd.DataFrame([feature_map], columns=FEATURES_ORDER)

    probability = float(app.state.model.predict_proba(features_df)[0][1])
    fall_detected = probability >= RISK_THRESHOLD
    notification_sent_count = 0
    notification_target_count = 0

    if fall_detected and payload.uid:
        notification_sent_count, notification_target_count = send_notification_to_user(
            payload.uid, feature_map, probability
        )
    elif fall_detected:
        print("Fall detected but no UID provided; skipping notification.")

    return PredictResponse(
        risk=round(probability, 4),
        risk_score=round(probability, 4),
        fall_detected=fall_detected,
        notification_attempted=fall_detected,
        notification_sent_count=notification_sent_count,
        notification_target_count=notification_target_count,
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


def send_notification_to_user(
    uid: str, feature_map: dict[str, Any], probability: float
) -> tuple[int, int]:
    global _last_push_sent_at

    now = time.time()
    last_sent = _last_push_sent_at.get(uid, 0.0)
    
    if (now - last_sent) < NOTIFICATION_COOLDOWN_SECONDS:
        print(
            f"FCM skipped for {uid}: cooldown active "
            f"({NOTIFICATION_COOLDOWN_SECONDS}s)"
        )
        return 0, 0
    
    _last_push_sent_at[uid] = now

    try:
        db = firestore.client()
        # Query the devices subcollection for the specific user
        # structure: users/{uid}/devices/{deviceId} -> {token: "..."}
        docs = db.collection("users").document(uid).collection("devices").stream()
        
        tokens: list[str] = []
        
        for doc in docs:
            data = doc.to_dict() or {}
            token_val = data.get("token")
            if isinstance(token_val, str) and token_val.strip():
                tokens.append(token_val.strip())

        if not tokens:
            print(f"No device tokens available for user {uid}")
            return 0, 0

        # Create the multicast message
        message = messaging.MulticastMessage(
            notification=messaging.Notification(
                title="Fall Detected",
                body="High fall risk detected",
            ),
            data={
                "type": "fall_risk",
                "risk": f"{probability:.4f}",
                "heart_rate": str(feature_map.get("heart_rate", "")),
                "body_posture": str(feature_map.get("body_posture", "")),
                "uid": uid,
            },
            tokens=tokens,
            android=messaging.AndroidConfig(
                priority="high",
                ttl=60 * 60,
                notification=messaging.AndroidNotification(
                    channel_id="fall_risk_alerts",
                    sound="default",
                    default_vibrate_timings=True,
                    default_light_settings=True,
                    visibility="public",
                    priority="high",
                ),
            ),
            webpush=messaging.WebpushConfig(
                notification=messaging.WebpushNotification(
                    title="Fall Detected",
                    body="High fall risk detected",
                    icon="/icons/Icon-192.png",
                ),
            ),
        )

        response = messaging.send_each_for_multicast(message)
        print(f"FCM batch sent: {response.success_count} success, {response.failure_count} failure")
        
        # Handle invalid tokens (cleanup)
        if response.failure_count > 0:
            for idx, resp in enumerate(response.responses):
                if not resp.success:
                    err_code = resp.exception.code if resp.exception else "unknown"
                    if err_code in ("registration-token-not-registered", "invalid-argument"):
                        invalid_token = tokens[idx]
                        print(f"Token invalid: {invalid_token}. (Cleanup not implemented for devices subcollection yet)")
                        # In a real app, you'd find the device doc with this token and delete it.

        return response.success_count, len(tokens)

    except Exception as e:
        print(f"FCM error for users/{uid}: {e}")
        return 0, 0
