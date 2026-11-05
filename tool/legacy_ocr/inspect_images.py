from PIL import Image
import os

art_dir = r'C:\Users\Thomas\AppData\Local\Google\AndroidStudio2026.1.4\projects\rapidrun.614aaaa\.artifacts\0baf10ab-8691-4ae0-a767-96242cc9a699'

for img_name in ['Capture1.PNG', 'Capture2.PNG', 'Capture3.PNG', 'Capture4.PNG']:
    p = os.path.join(art_dir, img_name)
    if os.path.exists(p):
        img = Image.open(p)
        print(f"• Image {img_name}: Size {img.size}, Format {img.format}, Mode {img.mode}")
