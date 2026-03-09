import random
import time
import requests
import csv
from datetime import datetime
import yagmail  # for sending emails

URL = "http://127.0.0.1:5000/predict"

FIELDS = [
    "chest_acc_x", "chest_acc_y", "chest_acc_z",
    "wrist_acc_x", "wrist_acc_y", "wrist_acc_z",
    "heart_rate", "body_posture"
]

# Email setup
sender_email = "vyshnavisrigiri@gmail.com"        # your email
receiver_email = "vyshnavisrigiri32@gmail.com"      # you receive the alert
yag = yagmail.SMTP(sender_email, "skillarpuqqayrej")     # app password

# Create CSV if not exists
with open("data/realtime_data.csv", "a", newline="") as f:
    writer = csv.writer(f)
    writer.writerow(["timestamp"] + FIELDS + ["risk"])

while True:
    # Random sensor simulation
    sensor_data = {
        "chest_acc_x": round(random.uniform(-2, 2), 2),
        "chest_acc_y": round(random.uniform(-2, 2), 2),
        "chest_acc_z": round(random.uniform(8, 12), 2),
        "wrist_acc_x": round(random.uniform(-2, 2), 2),
        "wrist_acc_y": round(random.uniform(-2, 2), 2),
        "wrist_acc_z": round(random.uniform(8, 12), 2),
        "heart_rate": random.randint(60, 120),
        "body_posture": random.randint(1, 4)
    }

    # Send to backend
    try:
        response = requests.post(URL, json=sensor_data)
        risk = response.json()["risk"]
    except Exception as e:
        print("❌ Could not connect to backend:", e)
        risk = 0  # default to safe

    # Print alert
    if risk == 1:
        print("⚠️ HIGH FALL RISK ALERT")
        
        # Custom email message
        subject = " FALL RISK ALERT!"
        body = f"""
Dear Sir/Madam,

Please don’t worry, but your concerned person is currently at HIGH FALL RISK.
Sensor readings indicate unusual levels, so please take care and monitor immediately.

Timestamp: {datetime.now()}
Sensor Data:
Chest Acc X: {sensor_data['chest_acc_x']}
Chest Acc Y: {sensor_data['chest_acc_y']}
Chest Acc Z: {sensor_data['chest_acc_z']}
Wrist Acc X: {sensor_data['wrist_acc_x']}
Wrist Acc Y: {sensor_data['wrist_acc_y']}
Wrist Acc Z: {sensor_data['wrist_acc_z']}
Heart Rate: {sensor_data['heart_rate']}
Body Posture: {sensor_data['body_posture']}

Stay safe,
Fall Prevention Monitoring System
"""
        yag.send(to=receiver_email, subject=subject, contents=body)
    else:
        print("✅ SAFE")

    # Store data
    with open("data/realtime_data.csv", "a", newline="") as f:
        writer = csv.writer(f)
        writer.writerow([datetime.now()] + list(sensor_data.values()) + [risk])

    # Wait 5 seconds (for fast testing)
    time.sleep(5)
