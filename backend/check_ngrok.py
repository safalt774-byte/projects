import urllib.request
import json
import sys

# Check ngrok
try:
    r = urllib.request.urlopen('http://127.0.0.1:4040/api/tunnels', timeout=3)
    data = json.loads(r.read())
    tunnels = data.get('tunnels', [])
    if tunnels:
        for t in tunnels:
            print(f"NGROK: {t['public_url']} -> {t['config']['addr']}")
    else:
        print("NGROK: Running but no tunnels")
except Exception as e:
    print(f"NGROK: Not running ({e})")

# Check backend
try:
    r = urllib.request.urlopen('http://localhost:8000/health', timeout=3)
    print(f"BACKEND: {r.read().decode()}")
except Exception as e:
    print(f"BACKEND: Not responding ({e})")

sys.stdout.flush()

