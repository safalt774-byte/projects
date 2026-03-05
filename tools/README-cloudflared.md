start-cloudflared-publish README

Purpose

This folder contains a PowerShell automation script `start-cloudflared-publish.ps1` that:
- Starts an ephemeral Cloudflare tunnel (trycloudflare) pointing at a local FastAPI server (default http://127.0.0.1:8000)
- Extracts the public trycloudflare URL from cloudflared stdout
- Publishes that URL to a stable GitHub Gist so mobile clients can read the latest URL automatically

Files
- start-cloudflared-publish.ps1  - PowerShell script to run cloudflared and update a gist

Prerequisites
- cloudflared installed on Windows (recommended path: `%ProgramFiles%\cloudflared\cloudflared.exe`)
  - Install with winget: `winget install --id Cloudflare.Cloudflared -e`
  - Or Chocolatey: `choco install cloudflared -y`
- A GitHub personal access token with `gist` scope (used by the machine where cloudflared runs)
- FastAPI running locally on port 8000 (or another port you pass as `-LocalPort`)

Usage

1) Create a GitHub token with gist scope:
   - Visit: https://github.com/settings/tokens (or Settings → Developer settings → Personal access tokens)
   - Generate a token and enable `gist` scope. Copy the token; keep it secret.

2) Optional: create a new Gist manually to use as the stable location (or allow the script to create one for you).
   - If you create one, note the Gist ID from the URL and pass it via `-GistId`.

3) Set a server token for your FastAPI (recommended). This prevents abuse if the trycloudflare URL is exposed.
   - In PowerShell (temporary for session):

```powershell
$env:TUNNEL_TOKEN = "my-secret-token"
python -m uvicorn api:app --host 0.0.0.0 --port 8000 --reload
```

   - Or set persistently for the current user (you must open a new shell for it to take effect):

```powershell
setx TUNNEL_TOKEN "my-secret-token"
# then start uvicorn in a new shell
python -m uvicorn api:app --host 0.0.0.0 --port 8000 --reload
```

The server expects clients to include the header `X-Tunnel-Token: my-secret-token` for protected endpoints. The Flutter app was updated to store and send this token when present.

4) Run the script (example - creates a new gist):

```powershell
PowerShell -ExecutionPolicy Bypass -File "C:\projects\tools\start-cloudflared-publish.ps1" -GitHubToken "ghp_YOURTOKEN" -LocalPort 8000
```

5) The script will print the raw gist URL (example):
   `https://gist.githubusercontent.com/<user>/<gistid>/raw/current_tunnel_url.txt`
   Use this raw URL in your mobile app (Settings → Auto-config) to let the app fetch the current trycloudflare URL automatically.

6) Mobile app setup (in-app):
   - Open Server Settings → Auto-config
   - Paste the raw gist URL and tap `Save config URL`.
   - Paste the `my-secret-token` in the `X-Tunnel-Token` field and tap `Save token`.
   - Tap `Fetch now` to pull the current trycloudflare URL from the gist and update the app's base URL.

Mobile client integration (Flutter / Dart) - brief
- On app startup, `ApiService.init()` attempts to fetch the current trycloudflare URL from the stored config raw URL (if available) and updates the base URL automatically.
- The app will include `X-Tunnel-Token` header automatically with API requests when you save the token in settings.
- Cache locally with a short TTL (30s-60s). On network failure, the app will re-fetch the gist and retry once.

Security note
- The gist contains only the public trycloudflare URL. Anyone with the raw gist URL can get the current public endpoint.
- Protect your FastAPI behind the `TUNNEL_TOKEN` as shown above. Mobile clients must send `X-Tunnel-Token` on protected endpoints.
- Keep the GitHub PAT local and do not commit it.

Troubleshooting
- If gist updates fail: verify your GitHub token has `gist` scope and the machine has outbound HTTPS access.
- If mobile clients get Host Lookup errors: open the raw gist URL in a browser and verify it contains a trycloudflare URL; then paste that URL in a browser to validate accessibility.
- If your TryCloudflare URL changes but the app still hits an old URL, make sure you saved the raw gist URL in the app settings and tapped `Fetch now` or restarted the app.

Next steps
- Optionally convert this to a Windows Scheduled Task or run as a background service wrapper (nssm) to start at boot.
- Consider acquiring a cheap domain and switching to a named Cloudflare tunnel for a permanent hostname (recommended).
