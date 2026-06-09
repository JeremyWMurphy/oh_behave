import tkinter as tk
from PIL import Image, ImageTk
from picamera2 import Picamera2
import time
import os
import sys

# Create output directory for captures
OUTPUT_DIR = "/home/pi/Desktop/captures"
os.makedirs(OUTPUT_DIR, exist_ok=True)

class CameraApp:
    def __init__(self, root):
        self.root = root
        self.root.title("PiCamera2 Live Preview - Press 'c' to Capture, 'q' to Quit")

        # Initialize camera
        self.picam2 = Picamera2()
        self.picam2.configure(self.picam2.create_preview_configuration(main={"size": (640, 480)}))
        self.picam2.start()

        # Tkinter label to display frames
        self.label = tk.Label(root)
        self.label.pack()

        # Bind keystrokes
        self.root.bind("<Key>", self.on_key)

        # Start updating frames
        self.update_frame()

    def update_frame(self):
        """Fetch frame from camera and update Tkinter label."""
        try:
            frame = self.picam2.capture_array()
            img = Image.fromarray(frame)
            imgtk = ImageTk.PhotoImage(image=img)
            self.label.imgtk = imgtk
            self.label.configure(image=imgtk)
        except Exception as e:
            print(f"Error capturing frame: {e}", file=sys.stderr)

        # Schedule next frame update
        self.root.after(30, self.update_frame)

    def on_key(self, event):
        """Handle key presses."""
        key = event.char.lower()
        if key == 'c':
            self.capture_image()
        elif key == 'q':
            self.quit_app()

    def capture_image(self):
        """Capture and save an image."""
        filename = os.path.join(OUTPUT_DIR, f"capture_{int(time.time())}.jpg")
        try:
            self.picam2.capture_file(filename)
            print(f"Image saved: {filename}")
        except Exception as e:
            print(f"Error saving image: {e}", file=sys.stderr)

    def quit_app(self):
        """Stop camera and close app."""
        print("Quitting application...")
        self.picam2.stop()
        self.root.destroy()

if __name__ == "__main__":
    root = tk.Tk()
    app = CameraApp(root)
    root.mainloop()

