from picamera2 import Picamera2, Preview, MappedArray
import cv2
from picamera2.encoders import H264Encoder, Quality
import RPi.GPIO as GPIO
import tkinter as tk
import libcamera as libcamera
import datetime
import time
import os.path
import io
import numpy as np

colour = (0, 255, 0)
origin = (0, 30)
font = cv2.FONT_HERSHEY_SIMPLEX
scale = 1
thickness = 2

cam = Picamera2()

config = cam.create_video_configuration({'size':(512,512)})
config["transform"] = libcamera.Transform(hflip=0, vflip=1)
encoder = H264Encoder()
cam.configure(config)

# ********************** initialize GPIO
GPIO.setmode(GPIO.BOARD)
# we are going to trigger via low->high
# so pull down the trigger pin (can emulate on chip)
# 12, GPIO18 is on trigger
GPIO.setup(12, GPIO.IN,pull_up_down=GPIO.PUD_DOWN)

# button callback fxns
def startPreview():
    preview_btn.configure(bg="gainsboro")
    cam.start_preview(Preview.QTGL)
    cam.start()
def stopPreview():
    preview_btn.configure(bg="#3CB371")
    cam.stop_preview()
def startRecord():
    start_btn.configure(bg="gainsboro")
    cStr=datetime.datetime.now().strftime("%Y-%m-%d_%H:%M:%S")
    filename = '/home/pi/Desktop/Captures/video_'+cStr+'.h264'
    waitForPin=1
    while waitForPin:
        checkPin=GPIO.input(12)
        if checkPin==1:
            waitForPin=0
    cam.pre_callback = apply_timestamp
    cam.start_recording(encoder, '/home/pi/Desktop/Captures/video_'+cStr+'.h264',quality=Quality.MEDIUM)
            
def stopRecord():
    start_btn.configure(bg="#3CB371")
    cam.stop_recording()
    
def takePicture():
    cStr=datetime.datetime.now().strftime("%Y-%m-%d_%H:%M:%S")
    filename = '/home/pi/Desktop/Captures/image_'+cStr+'.jpg'
    if os.path.isfile(filename):
        i+=1
        takePicture()
    else:
        cam.capture_file('/home/pi/Desktop/Captures/image_'+cStr+'.jpg') 
        i+=1

def apply_timestamp(request):
    timestamp = time.strftime("%Y-%m-%d %X")
    with MappedArray(request, "main") as m:
        cv2.putText(m.array, timestamp, origin, font, scale, colour, thickness)


# simple button GUI
window = tk.Tk()
window.title("Recording Controls")
preview_btn = tk.Button(window, text="Start Preview", command=startPreview, height=4, width=15, bg="#3CB371")
preview_btn.pack()
start_btn = tk.Button(window, text="Start Record", command=startRecord, height=4, width=15, bg="#3CB371")
start_btn.pack()
stop_btn = tk.Button(window, text="Stop Record", command=stopRecord, height=4, width=15, bg="#CD5C5C")
stop_btn.pack()
pic_btn = tk.Button(window, text="Take Picture", command=takePicture, height=4, width=15, bg="#FFFACD")
pic_btn.pack()
end_btn = tk.Button(window, text="Exit Preview", command=stopPreview, height=4, width=15)
end_btn.pack()
window.mainloop()




