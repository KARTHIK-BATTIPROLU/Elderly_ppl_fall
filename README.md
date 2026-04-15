# Elder Fall Prevention

A Flutter mobile and web monitoring client backed by FastAPI, a **BiLSTM (Bidirectional LSTM)** fall-risk model, Firestore logging, and Firebase Cloud Messaging.

## Architecture

Flutter Mobile + Web App
↓
Firebase Authentication
↓
FastAPI Backend
↓
BiLSTM Model Prediction (Sequence-based)
↓
Firestore Logging
↓
Firebase Cloud Messaging Push Notification

## Project Structure

- `backend_fastapi/` - FastAPI backend and Firebase Admin integration
- `training/` - LSTM model training scripts (preprocessing + training)
- `model/` - trained `bilstm_model.h5` and `scaler.pkl`
- `data/` - training and simulated realtime CSV data
- `fall_prevention_app/` - Flutter mobile and web app
- `simulate.py` - 5-second simulated sensor generator that posts to FastAPI

## 🆕 Model Migration: Random Forest → BiLSTM

The project has been upgraded from Random Forest to **Bidirectional LSTM** for better temporal pattern recognition.

### Key Improvements:
- ✅ **Temporal awareness**: Analyzes sequences of 20 timesteps instead of single points
- ✅ **Better accuracy**: Captures patterns over time (e.g., gradual posture changes)
- ✅ **Robust to noise**: Uses context from multiple data points

### Training the BiLSTM Model

See detailed instructions in [`training/README_LSTM.md`](training/README_LSTM.md)

**Quick start:**
```bash
cd training
python run_training_pipeline.py
```

This will:
1. Preprocess data into sequences (`processed_data.npz`)
2. Train BiLSTM model (`bilstm_model.h5`)
3. Generate evaluation plots

**Manual steps:**
```bash
# Step 1: Preprocess data
python preprocess_lstm.py

# Step 2: Train model
python train_bilstm.py
```

## Backend Setup

1. Create and activate a Python virtual environment.
2. Install dependencies (includes TensorFlow for LSTM):

```powershell
cd backend_fastapi
pip install -r requirements.txt
```

3. **Train the BiLSTM model** (if not already trained):

```powershell
cd ../training
python run_training_pipeline.py
```

4. Configure Firebase Admin credentials:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS="C:\path\to\service-account.json"
```

5. Run the backend:

```powershell
cd ../backend_fastapi
uvicorn main:app --host 0.0.0.0 --port 8002 --reload
```

**Note**: The backend now loads `bilstm_model.h5` instead of `rf_model.pkl`. Ensure the model is trained before starting the backend.

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

- Android emulator: `http://10.0.2.2:8002`
- Web on the same machine: `http://localhost:8002`
- Physical Android via USB reverse: `http://127.0.0.1:8002` (only after `adb reverse tcp:8002 tcp:8002`)
- Physical Android via LAN: `http://<your-pc-ip>:8002`

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
5. **FastAPI maintains a buffer of the last 20 data points per user**.
6. **FastAPI runs the BiLSTM model on the sequence** (20 timesteps × 8 features).
7. Predictions are logged to Firestore.
8. If a fall is detected, FastAPI sends an FCM push notification.

## How BiLSTM Prediction Works

Unlike Random Forest (single point), BiLSTM analyzes **sequences**:

1. **First prediction**: Buffer has only 1 point → Padded to 20 by repetition
2. **Subsequent predictions**: Buffer accumulates points (up to 20)
3. **After 20 predictions**: Buffer is full → Uses real temporal sequence
4. **Normalization**: Sequence is normalized using `scaler.pkl` before prediction

This approach provides:
- ✅ Immediate predictions (no waiting for buffer to fill)
- ✅ Improving accuracy as buffer fills
- ✅ Full temporal context after 20 data points

## Verification Checklist

- FastAPI health endpoint returns status ok.
- `simulate.py` posts sensor data every 5 seconds.
- Flutter analyze passes.
- Dashboard shows live sensor values and risk score.
- Firestore receives prediction, sensor, and alert documents.
- FCM notifications appear when `fall_detected` is true.
