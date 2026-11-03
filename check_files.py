import os

# Let's inspect the files
for f in ['Capture1.PNG', 'Capture2.PNG', 'Capture3.PNG', 'Capture4.PNG']:
    p = os.path.join(r'C:\Users\Thomas\OneDrive\Desktop', f)
    print(f"File {f}: Exists={os.path.exists(p)}, Size={os.path.getsize(p) if os.path.exists(p) else 0}")
