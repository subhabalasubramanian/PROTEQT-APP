import cv2

camera = cv2.VideoCapture(0)

if not camera.isOpened():
    print("Camera not detected!")
    exit()

print("PROTEQT Live Webcam Started")
print("Press Q to close")

while True:
    ret, frame = camera.read()

    if not ret:
        print("Camera frame unavailable")
        break

    cv2.imshow("PROTEQT Live Webcam", frame)

    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

camera.release()
cv2.destroyAllWindows()