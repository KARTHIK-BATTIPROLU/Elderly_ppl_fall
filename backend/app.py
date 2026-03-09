from flask import Flask, request, jsonify
from flask_cors import CORS
import joblib
import numpy as np
import pandas as pd
import yagmail
from datetime import datetime

app = Flask(__name__)
CORS(app)

# Load trained model
model = joblib.load("model/rf_model.pkl")

FEATURES_ORDER = [
    "chest_acc_x", "chest_acc_y", "chest_acc_z",
    "wrist_acc_x", "wrist_acc_y", "wrist_acc_z",
    "heart_rate", "body_posture"
]


@app.route("/predict", methods=["POST"])
def predict():
    data = request.json
    features = np.array([data[f] for f in FEATURES_ORDER]).reshape(1, -1)
    prediction = model.predict(features)[0]
    return jsonify({"risk": int(prediction)})


@app.route("/random-data", methods=["GET"])
def random_data():
    try:
        df = pd.read_csv("data/realtime_data.csv")
        # Drop rows that are duplicate headers
        df = df[df["chest_acc_x"] != "chest_acc_x"]
        row = df.sample(1).iloc[0]
        return jsonify({
            "chest_acc_x": float(row["chest_acc_x"]),
            "chest_acc_y": float(row["chest_acc_y"]),
            "chest_acc_z": float(row["chest_acc_z"]),
            "wrist_acc_x": float(row["wrist_acc_x"]),
            "wrist_acc_y": float(row["wrist_acc_y"]),
            "wrist_acc_z": float(row["wrist_acc_z"]),
            "heart_rate": int(float(row["heart_rate"])),
            "body_posture": int(float(row["body_posture"]))
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/send-alert", methods=["POST"])
def send_alert():
    data = request.json
    sender_email = data.get("sender_email")
    password = data.get("password")
    receiver_email = data.get("receiver_email")
    sensor_data = data.get("sensor_data", {})
    risk = data.get("risk", 0)

    if not all([sender_email, password, receiver_email]):
        return jsonify({"error": "Missing email configuration"}), 400

    try:
        yag = yagmail.SMTP(sender_email, password)
        subject = "FALL RISK ALERT!"
        body = f"""
Dear Sir/Madam,

Your concerned person is currently at HIGH FALL RISK.
Sensor readings indicate unusual levels. Please monitor immediately.

Timestamp: {datetime.now()}
Sensor Data:
  Chest Acc X: {sensor_data.get('chest_acc_x', 'N/A')}
  Chest Acc Y: {sensor_data.get('chest_acc_y', 'N/A')}
  Chest Acc Z: {sensor_data.get('chest_acc_z', 'N/A')}
  Wrist Acc X: {sensor_data.get('wrist_acc_x', 'N/A')}
  Wrist Acc Y: {sensor_data.get('wrist_acc_y', 'N/A')}
  Wrist Acc Z: {sensor_data.get('wrist_acc_z', 'N/A')}
  Heart Rate: {sensor_data.get('heart_rate', 'N/A')}
  Body Posture: {sensor_data.get('body_posture', 'N/A')}
Risk Level: {risk}

Stay safe,
Fall Prevention Monitoring System
"""
        yag.send(to=receiver_email, subject=subject, contents=body)
        return jsonify({"status": "alert_sent"})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0")
