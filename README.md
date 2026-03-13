# Elder Fall Prevention

A Flutter mobile and web monitoring client backed by FastAPI, a Random Forest fall-risk model, Firestore logging, and Firebase Cloud Messaging.

## Architecture

Flutter Mobile + Web App
↓
Firebase Authentication
↓
FastAPI Backend
↓
ML Model Prediction
↓
Firestore Logging
↓
Firebase Cloud Messaging Push Notification

## Project Structure

- `backend_fastapi/` - FastAPI backend and Firebase Admin integration
- `training/` - model training script
- `model/` - trained `rf_model.pkl`
- `data/` - training and simulated realtime CSV data
- `fall_prevention_app/` - Flutter mobile and web app
- `simulate.py` - 5-second simulated sensor generator that posts to FastAPI

## Backend Setup

1. Create and activate a Python virtual environment.
2. Install dependencies:

```powershell
pip install -r requirements.txt
```

3. Configure Firebase Admin credentials:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS="C:\path\to\service-account.json"
```

4. Run the backend:

```powershell
cd backend_fastapi
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

## Simulation

Run the simulator in a separate terminal:

```powershell
c:/Users/Karthik/OneDrive/Desktop/Elder-fall-prevention-main/.venv/Scripts/python.exe simulate.py
```

The simulator generates a sensor sample every 5 seconds and posts it to `POST /predict`.

## Flutter Setup

1. Install Flutter dependencies:

```powershell
cd fall_prevention_app
flutter pub get
```

2. Run on mobile:

```powershell
flutter run
```

3. Run on web:

```powershell
flutter run -d chrome --web-port 8090 --dart-define=FCM_WEB_VAPID_KEY=<your-vapid-key>
```

## Backend URL

Set the server URL on the Flutter login/configuration screen to:

- Android emulator: `http://10.0.2.2:8000`
- Web on the same machine: `http://localhost:8000`
- Physical Android via USB reverse: `http://127.0.0.1:8000`
- Physical Android via LAN: `http://<your-pc-ip>:8000`

## API Endpoints

- `GET /health`
- `GET /random-data`
- `POST /predict`

`POST /predict` returns:

```json
{
  "risk": 0.62,
  "fall_detected": true
}
```

## Runtime Flow

1. Flutter starts and initializes Firebase.
2. The app signs in anonymously with Firebase Auth.
3. The app initializes FCM and stores `users/{uid}/device_token` in Firestore.
4. Every 5 seconds the dashboard fetches `/random-data` and sends it to `/predict`.
5. FastAPI runs the ML model.
6. Predictions are logged to Firestore.
7. If a fall is detected, FastAPI sends an FCM push notification.

## Verification Checklist

- FastAPI health endpoint returns status ok.
- `simulate.py` posts sensor data every 5 seconds.
- Flutter analyze passes.
- Dashboard shows live sensor values and risk score.
- Firestore receives prediction, sensor, and alert documents.
- FCM notifications appear when `fall_detected` is true.
