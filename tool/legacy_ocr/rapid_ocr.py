from rapidocr_onnxruntime import RapidOCR
import os

engine = RapidOCR()

desktop = r'C:\Users\Thomas\OneDrive\Desktop'

for f in ['Capture1.PNG', 'Capture2.PNG', 'Capture3.PNG', 'Capture4.PNG']:
    p = os.path.join(desktop, f)
    if os.path.exists(p):
        res, _ = engine(p)
        print(f"\n==========================================")
        print(f"=== TEXT EXTRACTED FROM {f} ===")
        if res:
            for line in res:
                text = line[1]
                confidence = line[2]
                print(f"  • {text}")
        else:
            print("  (No text detected)")
