import subprocess
import requests
import sys

try:
    token = subprocess.check_output(['gcloud', 'auth', 'print-identity-token']).decode().strip()
except Exception as e:
    print('Failed to get identity token via gcloud:', e)
    sys.exit(1)

url = 'https://us-central1-quest-cards-3c47a.cloudfunctions.net/backfill_uploader_emails'
headers = {'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}

try:
    resp = requests.post(url, headers=headers, json={})
    print('status:', resp.status_code)
    print('body:', resp.text)
except Exception as e:
    print('Request failed:', e)
    sys.exit(1)
