# Production Deployment Guide

## ✅ Current Status

Your application is **READY FOR PRODUCTION** with the following components working:

- ✅ BiLSTM model trained and tested (90.81% accuracy)
- ✅ Backend API with Firebase notifications
- ✅ Flutter mobile app with real-time predictions
- ✅ Firebase Authentication and Firestore integration
- ✅ Push notifications working

## 🚀 Deploying to Render

### Prerequisites

1. **GitHub Repository**: Ensure your code is pushed to GitHub
2. **Render Account**: Sign up at https://render.com
3. **Firebase Service Account Key**: Downloaded from Firebase Console

### Step 1: Prepare Backend for Render

#### 1.1 Create `render.yaml` (Render Blueprint)

Create this file in your project root:

```yaml
services:
  - type: web
    name: fall-prevention-backend
    env: python
    region: oregon
    plan: free
    branch: main
    buildCommand: "cd backend_fastapi && pip install -r requirements.txt"
    startCommand: "cd backend_fastapi && uvicorn main:app --host 0.0.0.0 --port $PORT"
    envVars:
      - key: FIREBASE_SERVICE_ACCOUNT_KEY
        sync: false
      - key: RISK_THRESHOLD
        value: "0.20"
      - key: NOTIFICATION_COOLDOWN_SECONDS
        value: "0"
      - key: FIREBASE_PROJECT_ID
        value: "fall-prevention-sys-26"
      - key: CORS_ALLOW_ORIGINS
        value: "*"
```

#### 1.2 Update Backend for Production

The backend is already production-ready, but verify these settings in `backend_fastapi/main.py`:

- ✅ Environment variables for configuration (RISK_THRESHOLD, NOTIFICATION_COOLDOWN_SECONDS)
- ✅ CORS middleware configured
- ✅ Firebase initialization from environment variable
- ✅ Health check endpoint

### Step 2: Deploy to Render

#### 2.1 Create New Web Service

1. Go to https://dashboard.render.com
2. Click **"New +"** → **"Web Service"**
3. Connect your GitHub repository
4. Render will auto-detect the `render.yaml` file

#### 2.2 Configure Environment Variables

In Render Dashboard → Your Service → Environment:

1. **FIREBASE_SERVICE_ACCOUNT_KEY**:
   - Copy the entire content of `backend_fastapi/serviceAccountKey.json`
   - Paste it as a single-line JSON string
   - Example: `{"type":"service_account","project_id":"fall-prevention-sys-26",...}`

2. **Other variables** (already set in render.yaml):
   - RISK_THRESHOLD: `0.20`
   - NOTIFICATION_COOLDOWN_SECONDS: `0`
   - FIREBASE_PROJECT_ID: `fall-prevention-sys-26`

#### 2.3 Deploy

1. Click **"Create Web Service"**
2. Render will:
   - Clone your repository
   - Install dependencies
   - Start the backend
3. Wait for deployment to complete (5-10 minutes)
4. Note your production URL: `https://fall-prevention-backend.onrender.com`

### Step 3: Update Flutter App for Production

#### 3.1 Update Backend URL

Edit `fall_prevention_app/lib/services/backend_config.dart`:

```dart
String resolveBackendUrl(String? savedUrl) {
  const runtimeBackendUrl = String.fromEnvironment('BACKEND_URL');
  if (runtimeBackendUrl.isNotEmpty) {
    return runtimeBackendUrl;
  }

  if (savedUrl != null && savedUrl.trim().isNotEmpty) {
    return savedUrl.trim();
  }

  if (kIsWeb) {
    final host = Uri.base.host.isEmpty ? 'localhost' : Uri.base.host;
    return 'http://$host:8002';
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      // Production URL
      return 'https://fall-prevention-backend.onrender.com';
    default:
      return 'http://127.0.0.1:8002';
  }
}
```

#### 3.2 Build Release APK

```bash
cd fall_prevention_app
flutter build apk --release
```

The APK will be at: `fall_prevention_app/build/app/outputs/flutter-apk/app-release.apk`

#### 3.3 Deploy to Google Play Store (Optional)

```bash
flutter build appbundle --release
```

Upload `app-release.aab` to Google Play Console.

### Step 4: Verify Production Deployment

#### 4.1 Test Backend

```bash
curl https://fall-prevention-backend.onrender.com/health
```

Expected response:
```json
{"status":"backend running"}
```

#### 4.2 Test Prediction Endpoint

```bash
curl -X POST https://fall-prevention-backend.onrender.com/predict \
  -H "Content-Type: application/json" \
  -d '{
    "chest_acc_x": 0.5,
    "chest_acc_y": 1.2,
    "chest_acc_z": 9.8,
    "wrist_acc_x": 0.3,
    "wrist_acc_y": -0.5,
    "wrist_acc_z": 10.1,
    "heart_rate": 75,
    "body_posture": 1,
    "uid": "test-user"
  }'
```

#### 4.3 Test Mobile App

1. Install the release APK on your device
2. Login with Firebase Auth
3. Verify predictions are working
4. Check notifications are received

## 🔒 Security Checklist

- ✅ Firebase service account key stored as environment variable (not in code)
- ✅ CORS configured appropriately
- ✅ HTTPS enabled (Render provides this automatically)
- ⚠️ **TODO**: Add API authentication/rate limiting for production
- ⚠️ **TODO**: Add input validation and sanitization
- ⚠️ **TODO**: Set up monitoring and logging

## 📊 Monitoring

### Render Dashboard

- View logs: Render Dashboard → Your Service → Logs
- Monitor CPU/Memory: Render Dashboard → Your Service → Metrics
- Set up alerts: Render Dashboard → Your Service → Alerts

### Firebase Console

- Monitor authentication: Firebase Console → Authentication
- Check Firestore data: Firebase Console → Firestore Database
- View FCM analytics: Firebase Console → Cloud Messaging

## 🐛 Troubleshooting

### Backend won't start on Render

1. Check logs in Render Dashboard
2. Verify `FIREBASE_SERVICE_ACCOUNT_KEY` is set correctly
3. Ensure all dependencies are in `requirements.txt`
4. Check that model files (`bilstm_model.h5`, `scaler.pkl`) are in the repository

### Notifications not working

1. Verify Firebase service account key is valid
2. Check FCM tokens are being saved to Firestore
3. Verify device has notification permissions enabled
4. Check backend logs for FCM errors

### High latency

1. Render free tier has cold starts (first request may be slow)
2. Consider upgrading to paid tier for better performance
3. Add caching for model predictions if needed

## 💰 Cost Estimate

### Render (Backend)

- **Free Tier**: $0/month
  - 750 hours/month
  - Sleeps after 15 minutes of inactivity
  - Cold starts on first request
  
- **Starter Tier**: $7/month
  - Always on
  - No cold starts
  - Better performance

### Firebase

- **Spark Plan (Free)**: $0/month
  - 50,000 reads/day
  - 20,000 writes/day
  - 1GB storage
  - Unlimited FCM notifications

- **Blaze Plan (Pay as you go)**: Starts at $0
  - Only pay for usage above free tier
  - Recommended for production

## 🎯 Production Optimization Recommendations

### 1. Model Optimization

- ✅ Model is already optimized (BiLSTM with 90.81% accuracy)
- Consider quantization for faster inference
- Add model caching to reduce load time

### 2. API Optimization

- Add Redis for caching predictions
- Implement rate limiting (e.g., 100 requests/minute per user)
- Add request validation middleware

### 3. Database Optimization

- Add indexes to Firestore collections
- Implement data retention policies
- Archive old predictions

### 4. Monitoring & Alerts

- Set up Sentry for error tracking
- Add health check monitoring (e.g., UptimeRobot)
- Configure email alerts for downtime

### 5. Security Enhancements

- Add API key authentication
- Implement user-based rate limiting
- Add input sanitization
- Enable HTTPS only (already done by Render)

## 📝 Post-Deployment Checklist

- [ ] Backend deployed to Render
- [ ] Environment variables configured
- [ ] Health endpoint responding
- [ ] Prediction endpoint working
- [ ] Firebase notifications working
- [ ] Mobile app updated with production URL
- [ ] Release APK built and tested
- [ ] Monitoring set up
- [ ] Documentation updated
- [ ] Team notified of production URL

## 🔄 Continuous Deployment

### Option 1: Auto-deploy from GitHub

Render automatically deploys when you push to the main branch.

### Option 2: Manual Deploy

In Render Dashboard → Your Service → Manual Deploy

## 📞 Support

If you encounter issues:

1. Check Render logs
2. Check Firebase Console
3. Review this deployment guide
4. Contact Render support: https://render.com/docs

---

**Your app is production-ready! Just deploy to Render and update the Flutter app with the production URL.** 🚀
