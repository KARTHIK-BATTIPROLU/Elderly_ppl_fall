import firebase_admin
from firebase_admin import credentials, firestore, messaging
from pathlib import Path
import sys
import os

# --- CONFIGURATION ---
UID_TO_CHECK = os.getenv("TEST_UID", "YOUR_TEST_USER_UID")  # Replace with a real UID to test
SERVICE_ACCOUNT_KEY = Path("serviceAccountKey.json")

def step_1_check_credentials():
    print("\n--- STEP 1: CREDENTIALS CHECK ---")
    if not SERVICE_ACCOUNT_KEY.exists():
        print("❌ ERROR: serviceAccountKey.json NOT FOUND in project root.")
        print("   Fix: Download from Firebase Console -> Project Settings -> Service Accounts.")
        print("   Action: Place the JSON file in this directory.")
        return False
    
    try:
        cred = credentials.Certificate(str(SERVICE_ACCOUNT_KEY))
        if not firebase_admin._apps:
            firebase_admin.initialize_app(cred)
        print("✅ Firebase Admin initialized with service account.")
        return True
    except Exception as e:
        print(f"❌ ERROR: Failed to initialize Firebase Admin: {e}")
        return False

def step_2_check_firestore_tokens(uid):
    print(f"\n--- STEP 2: FIRESTORE TOKEN CHECK for UID={uid} ---")
    try:
        db = firestore.client()
        # Query: users/{uid}/devices
        docs = db.collection("users").document(uid).collection("devices").stream()
        
        tokens = []
        for doc in docs:
            data = doc.to_dict()
            token = data.get("token")
            device_id = doc.id
            if token:
                print(f"   Found Device: {device_id} -> Token: {token[:10]}...")
                tokens.append(token)
            else:
                print(f"⚠️ WARNING: Device {device_id} has missing 'token' field.")

        if not tokens:
            print(f"❌ ERROR: No valid tokens found for user {uid}.")
            print("   Possible causes:")
            print("   1. User has not logged in via the app.")
            print("   2. App saving logic failed (check Flutter logs).")
            print("   3. Firestore path mismatch (code expects 'devices' subcollection).")
            return []
        
        print(f"✅ Found {len(tokens)} valid token(s).")
        return tokens

    except Exception as e:
        print(f"❌ ERROR: Firestore read failed: {e}")
        return []

def step_3_test_fcm_send(tokens):
    print(f"\n--- STEP 3: TEST NOTIFICATION SEND ({len(tokens)} tokens) ---")
    
    success_count = 0
    failure_count = 0

    # Sending multicast to all tokens
    message = messaging.MulticastMessage(
        notification=messaging.Notification(
            title="Test Notification",
            body="This is a test from the backend debugger.",
        ),
        tokens=tokens,
    )

    try:
        response = messaging.send_each_for_multicast(message)
        print(f"✅ FCM Batch Response: {response.success_count} success, {response.failure_count} failure")
        
        if response.failure_count > 0:
            for idx, resp in enumerate(response.responses):
                if not resp.success:
                    print(f"❌ Failed to send to token {tokens[idx][:10]}...: {resp.exception}")
        
        if response.success_count > 0:
            print("✅ At least one notification sent successfully!")
        else:
            print("❌ All notifications failed.")

    except Exception as e:
        print(f"❌ ERROR: FCM Send Failed: {e}")

if __name__ == "__main__":
    print("=== NOTIFICATION SYSTEM DEBUGGER ===")
    
    if len(sys.argv) > 1:
        UID_TO_CHECK = sys.argv[1]
    
    if step_1_check_credentials():
        # Auto-discover UID if default
        if UID_TO_CHECK == "YOUR_TEST_USER_UID":
            print("\n--- AUTO-DISCOVERING USER ---")
            try:
                db = firestore.client()
                users = list(db.collection("users").limit(1).stream())
                if users:
                    UID_TO_CHECK = users[0].id
                    print(f"✅ Found user: {UID_TO_CHECK}")
                else:
                    print("❌ No users found in Firestore. Please login via the app first.")
                    sys.exit(1)
            except Exception as e:
                print(f"❌ Failed to list users: {e}")
                sys.exit(1)

        tokens = step_2_check_firestore_tokens(UID_TO_CHECK)
        if tokens:
            step_3_test_fcm_send(tokens)
    
    print("\n=== DEBUG COMPLETE ===")
