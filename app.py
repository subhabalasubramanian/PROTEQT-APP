
from flask import Flask, jsonify
import cv2
import os
import hashlib
import requests
import getpass
from datetime import datetime
from threading import Lock

app = Flask(__name__)

# PROTEQT Android receiver
# Change this IP if your phone's IP changes.
PHONE_URL = "http://10.160.111.101:8765"

SAVE_DIR = "captured_images"
os.makedirs(SAVE_DIR, exist_ok=True)

camera_lock = Lock()

TOKEN = None
paired = False


def pair_with_proteqt():
    global paired

    try:
        response = requests.post(
            f"{PHONE_URL}/pair",
            headers={"x-proteqt-token": TOKEN},
            timeout=15
        )

        if response.status_code == 200:
            paired = True
            print("SUCCESS: PROTEQT pairing successful!")
            return True

        paired = False
        print("Pairing failed:", response.status_code)
        print(response.text)

    except requests.RequestException as error:
        paired = False
        print("Phone connection failed:", error)

    return False


def upload_to_proteqt(filepath):
    global paired

    try:
        if not paired and not pair_with_proteqt():
            print("Cannot upload: PROTEQT pairing unavailable.")
            return False

        with open(filepath, "rb") as photo:
            image_bytes = photo.read()

        filename = os.path.basename(filepath)
        file_hash = hashlib.sha256(image_bytes).hexdigest()

        headers = {
            "x-proteqt-token": TOKEN,
            "x-filename": filename,
            "x-sha256": file_hash,
            "Content-Type": "application/octet-stream"
        }

        response = requests.post(
            f"{PHONE_URL}/upload",
            headers=headers,
            data=image_bytes,
            timeout=30
        )

        print("PROTEQT upload response:", response.status_code)
        print(response.text)

        return response.status_code == 200

    except requests.RequestException as error:
        print("Photo upload failed:", error)
        return False


def send_hardware_alert():
    global paired

    try:
        if not paired and not pair_with_proteqt():
            print("Hardware alert skipped: pairing unavailable.")
            return {
                "accepted": False,
                "error": "Pairing unavailable"
            }

        headers = {
            "x-proteqt-token": TOKEN,
            "Content-Type": "application/json"
        }

        response = requests.post(
            f"{PHONE_URL}/hardware-alert",
            headers=headers,
            json={},
            timeout=60
        )

        print("Hardware alert response:", response.status_code)
        print(response.text)

        try:
            result = response.json()
        except ValueError:
            result = {"response": response.text}

        result["http_status"] = response.status_code
        result["accepted"] = (
            response.status_code == 200
            and result.get("accepted") is True
        )

        return result

    except requests.RequestException as error:
        print("Hardware alert failed:", error)
        return {
            "accepted": False,
            "error": str(error)
        }


def capture_photo():
    with camera_lock:
        camera = cv2.VideoCapture(0)

        if not camera.isOpened():
            print("ERROR: Webcam unavailable.")
            return None

        try:
            ret, frame = camera.read()
        finally:
            camera.release()

        if not ret:
            print("ERROR: Webcam capture failed.")
            return None

        filename = (
            "PROTEQT_"
            + datetime.now().strftime("%Y%m%d_%H%M%S_%f")
            + ".jpg"
        )

        filepath = os.path.join(SAVE_DIR, filename)

        if not cv2.imwrite(filepath, frame):
            print("ERROR: Unable to save photo.")
            return None

    print("Photo saved locally:", filepath)
    return filepath


@app.route("/capture", methods=["GET"])
def capture():
    print("\n===================================")
    print("PROTEQT HARDWARE SWITCH ACTIVATED")
    print("===================================")

    # Attempt photo capture.
    filepath = capture_photo()

    uploaded = False
    filename = None

    if filepath:
        filename = os.path.basename(filepath)
        uploaded = upload_to_proteqt(filepath)

        if uploaded:
            print("SUCCESS: Photo transferred to Evidence Vault!")
        else:
            print("WARNING: Photo was not transferred.")

    # Send emergency alert independently of camera success.
    alert_result = send_hardware_alert()

    print("SMS result:", alert_result.get("sms_sent"))
    print("Call result:", alert_result.get("call_initiated"))

    return jsonify({
        "status": "switch_trigger_processed",
        "filename": filename,
        "local_saved": filepath is not None,
        "proteqt_uploaded": uploaded,
        "hardware_alert": alert_result
    })


if __name__ == "__main__":
    TOKEN = getpass.getpass(
        "Enter PROTEQT pairing token: "
    ).strip()

    if len(TOKEN) < 32:
        raise SystemExit("Invalid pairing token length.")

    pair_with_proteqt()

    app.run(
        host="0.0.0.0",
        port=5000,
        threaded=True
    )
