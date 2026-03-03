# AGENTS.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

Guitar practice app: users upload PDF sheet music, which is processed through OMR (Optical Music Recognition) into a scrolling Guitar Hero-style fretboard visualization synced with audio playback.

**Stack:** Flutter frontend (Dart) + FastAPI backend (Python). Firebase for auth/storage.

## Build & Run Commands

### Flutter frontend
```
flutter pub get              # Install dependencies
flutter run                  # Run on connected device/emulator
flutter analyze              # Static analysis (uses flutter_lints)
flutter test                 # Run widget tests
flutter test test/widget_test.dart  # Run a single test file
flutter build apk            # Build Android APK
```

### Python backend
```
cd backend
python -m venv venv
venv\Scripts\activate        # Windows activation
pip install fastapi uvicorn mido music21 python-multipart
uvicorn api:app --reload     # Start dev server
```

The backend requires **Audiveris** (installed at `C:\Program Files\Audiveris\Audiveris.exe`) and **FluidSynth** (on PATH) with the `FluidR3_GM.sf2` soundfont in `backend/`.

The backend is exposed to the mobile app via **ngrok**. When the ngrok URL changes, update `_baseUrl` in `lib/services/api_service.dart`.

## Architecture

### Data Flow (end-to-end)
1. User picks a PDF of sheet music (PdfPickerPage → PdfViewPage)
2. PDF is uploaded to FastAPI backend via multipart POST to `/process-sheet/`
3. Backend pipeline: **PDF → Audiveris OMR → MXL → MusicXML → music21 MIDI → mido timing parse + FluidSynth WAV**
4. API returns `{ "notes": [...], "audioPath": "outputs/{id}/{id}.wav" }`
5. Flutter app maps each note's MIDI pitch to guitar string+fret via `MidiMapper`
6. `PracticePage` downloads the WAV, plays it via `audioplayers`, and drives `FretboardHighwayPainter` with a `Ticker` for frame-synced animation

### Flutter App (`lib/`)
- **`main.dart`** — Entry point. Initializes Firebase, locks to portrait, launches LoginPage.
- **`screens/`** — Page-level widgets following the flow: Login → Signup → PdfPicker → PdfView → Practice
- **`services/api_service.dart`** — HTTP client for the backend. Contains the ngrok base URL. Returns `SheetProcessResult` (notes + audio URL).
- **`services/midi_mapper.dart`** — Pure logic: converts MIDI pitch (40–88) to `(stringIndex, fret)` using standard guitar tuning (EADGBE). Uses positional preference regions to spread notes across strings naturally.
- **`models/note_event.dart`** — Data class for a single note. API returns seconds; `fromJson` converts to milliseconds. Stores both raw MIDI pitch and mapped guitar position.
- **`widgets/fretboard_highway_painter.dart`** — **Active** CustomPainter. Scrolling tab view: playhead fixed at 30% from left, notes scroll right-to-left at 180px/sec. Color-coded by string.
- **`widgets/fretboard_painter.dart`** and **`widgets/highway_painter.dart`** — **Commented out** earlier iterations. Not in use.

### Backend (`backend/api.py`)
Single-file FastAPI server. One endpoint: `POST /process-sheet/`. Pipeline steps are numbered 1–7 in the code. Outputs are served as static files via `/outputs/`.

## Key Implementation Details

- **Audio sync**: `PracticePage` uses `AudioPlayer.onPositionChanged` as the timing source, with a user-adjustable `_syncOffsetMs` slider (±500ms) for calibration.
- **ngrok header**: All HTTP requests to the backend must include `ngrok-skip-browser-warning: true` to avoid the ngrok interstitial page.
- **Guitar range**: MidiMapper returns `null` for pitches outside 40–88 (below low E or above fret 12 on high e). These notes are silently skipped.
- **Orientation**: App is portrait-locked by default; PracticePage switches to landscape for the fretboard view and restores portrait on dispose.
- **String indexing**: 0=high e, 1=B, 2=G, 3=D, 4=A, 5=low E (top to bottom visually).
