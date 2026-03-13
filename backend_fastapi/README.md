# FastAPI Backend for Fall Risk System

## Install dependencies

```powershell
cd backend_fastapi
pip install -r requirements.txt
```

## Configure Firebase Admin credentials

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS="C:\path\to\service-account.json"
```

## Run server

```powershell
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

## API endpoints

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

## Authentication

Flutter signs in anonymously with Firebase Auth and sends:

`Authorization: Bearer <id_token>`

The backend accepts unauthenticated simulator traffic for prediction, but authenticated Flutter requests are used for user-bound push notifications.

## High-risk notification flow

When `fall_detected` is true and a valid Firebase user is present:

1. The backend loads `users/{uid}` from Firestore.
2. It reads `device_token`.
3. It sends an FCM push notification with title `Fall Risk Detected`.

## Web support

Set `CORS_ALLOW_ORIGINS=*` to allow web dashboard access and pass the web VAPID key when running Flutter web.
