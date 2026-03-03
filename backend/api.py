import os
import uuid
import zipfile
import subprocess
import time
import asyncio
import base64
from concurrent.futures import ThreadPoolExecutor

from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse

import mido
from PyPDF2 import PdfReader, PdfWriter


app = FastAPI()

@app.get("/")
def root():
    return {"status": "ok", "message": "API is running"}



# Thread pool for running blocking Audiveris/FluidSynth processing
# without blocking the async event loop (so audio serving still works)
_executor = ThreadPoolExecutor(max_workers=2)

# Track background page processing status
# key: "{job_id}_page_{page_num}"
# value: {"status": "processing"|"done"|"error", "notes": [...], "audioUrl": "...", "error": "..."}
_page_tasks: dict = {}

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
UPLOAD_DIR = os.path.join(BASE_DIR, "uploads")
OUTPUT_DIR = os.path.join(BASE_DIR, "outputs")
SOUNDFONT = os.path.join(BASE_DIR, "FluidR3_GM.sf2")

AUDIVERIS = r"C:\Program Files\Audiveris\Audiveris.exe"
FLUIDSYNTH = "fluidsynth"

os.makedirs(UPLOAD_DIR, exist_ok=True)
os.makedirs(OUTPUT_DIR, exist_ok=True)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/outputs", StaticFiles(directory=OUTPUT_DIR), name="outputs")


def parse_midi_timing(midi_path):
    mid = mido.MidiFile(midi_path)
    notes = []
    active_notes = {}
    current_time_seconds = 0.0
    tempo = 500000

    for track in mid.tracks:
        current_time_seconds = 0.0
        for msg in track:
            delta_seconds = mido.tick2second(msg.time, mid.ticks_per_beat, tempo)
            current_time_seconds += delta_seconds
            if msg.type == 'set_tempo':
                tempo = msg.tempo
            if msg.type == 'note_on' and msg.velocity > 0:
                active_notes[msg.note] = current_time_seconds
            if msg.type == 'note_off' or (msg.type == 'note_on' and msg.velocity == 0):
                if msg.note in active_notes:
                    start_time = active_notes.pop(msg.note)
                    duration = current_time_seconds - start_time
                    notes.append({
                        "pitch": msg.note,
                        "start": round(start_time, 4),
                        "duration": round(max(duration, 0.05), 4)
                    })
    notes.sort(key=lambda x: x['start'])
    return notes


def find_musicxml(job_dir):
    """Find the actual MusicXML file, skipping container.xml and META-INF"""
    for root, dirs, files in os.walk(job_dir):
        for f in files:
            full_path = os.path.join(root, f)
            if "META-INF" in full_path:
                continue
            if f.lower() == "container.xml":
                continue
            if f.endswith(".xml"):
                return full_path
    return None


def process_pdf_to_notes_and_audio(pdf_path, work_dir, file_id):
    """
    Full pipeline: PDF → Audiveris → MXL → XML → MIDI → Notes + WAV
    Returns (notes_list, wav_path) or (None, None) on failure
    """
    os.makedirs(work_dir, exist_ok=True)

    # Audiveris
    process = subprocess.Popen(
        [AUDIVERIS, "-batch", "-export", "-output", work_dir, pdf_path],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    )
    start = time.time()
    while True:
        if process.poll() is not None:
            break
        if time.time() - start > 300:
            process.kill()
            process.wait()
            break
        time.sleep(2)

    # Find MXL
    mxl_files = [os.path.join(r, f) for r, _, fs in os.walk(work_dir) for f in fs if f.endswith(".mxl")]
    if not mxl_files:
        return None, None

    # Extract MXL
    try:
        with zipfile.ZipFile(mxl_files[0], 'r') as z:
            z.extractall(work_dir)
    except:
        return None, None

    # Find XML
    xml_path = find_musicxml(work_dir)
    if not xml_path:
        return None, None

    # XML → MIDI
    midi_path = os.path.join(work_dir, f"{file_id}.mid")
    xml_escaped = xml_path.replace("\\", "\\\\")
    midi_escaped = midi_path.replace("\\", "\\\\")

    try:
        subprocess.run(
            ["python", "-c",
             f'from music21 import converter; '
             f'score = converter.parse("{xml_escaped}"); '
             f'score.write("midi", "{midi_escaped}")'],
            timeout=120, capture_output=True, text=True, check=True
        )
    except:
        return None, None

    if not os.path.exists(midi_path):
        return None, None

    notes = parse_midi_timing(midi_path)
    if not notes:
        return None, None

    # MIDI → WAV
    wav_path = os.path.join(work_dir, f"{file_id}.wav")
    try:
        subprocess.run(
            [FLUIDSYNTH, "-T", "wav", "-F", wav_path, SOUNDFONT, midi_path],
            timeout=120, capture_output=True, text=True, check=True
        )
    except:
        return notes, None

    if not os.path.exists(wav_path) or os.path.getsize(wav_path) < 1000:
        return notes, None

    return notes, wav_path


def read_wav_as_base64(wav_path):
    """Read a WAV file and return base64-encoded string"""
    if wav_path and os.path.exists(wav_path) and os.path.getsize(wav_path) > 1000:
        with open(wav_path, "rb") as f:
            return base64.b64encode(f.read()).decode("ascii")
    return None


@app.get("/audio/{job_id}/{file_name}")
async def get_audio(job_id: str, file_name: str):
    """Serve audio with correct WAV headers — supports Range requests for large files"""
    print(f"🔊 Audio request: {job_id}/{file_name}")

    # Check in job root
    wav_path = os.path.join(OUTPUT_DIR, job_id, file_name)
    if not os.path.exists(wav_path):
        # Check in page subdirectories
        job_root = os.path.join(OUTPUT_DIR, job_id)
        if os.path.exists(job_root):
            for root, dirs, files in os.walk(job_root):
                if file_name in files:
                    wav_path = os.path.join(root, file_name)
                    print(f"  📁 Found in subdirectory: {wav_path}")
                    break

    if not os.path.exists(wav_path):
        print(f"  ❌ Audio not found: {wav_path}")
        raise HTTPException(status_code=404, detail="Audio not found")

    file_size = os.path.getsize(wav_path)
    print(f"  ✅ Serving: {wav_path} ({file_size} bytes)")

    return FileResponse(
        path=wav_path,
        media_type="audio/wav",
        filename=file_name,
        headers={
            "Content-Type": "audio/wav",
            "Content-Length": str(file_size),
            "Cache-Control": "no-cache, no-store",
            "Accept-Ranges": "bytes",
            "Connection": "keep-alive",
        }
    )


@app.post("/process-sheet/")
async def process_sheet(file: UploadFile = File(...)):
    start_time = time.time()
    print(f"\n📥 RECEIVED: {file.filename}")

    job_id = str(uuid.uuid4())
    job_dir = os.path.join(OUTPUT_DIR, job_id)
    os.makedirs(job_dir, exist_ok=True)

    file_content = await file.read()
    file_size_kb = len(file_content) / 1024
    print(f"📊 Size: {file_size_kb:.1f} KB")

    pdf_path = os.path.join(job_dir, f"{job_id}.pdf")
    with open(pdf_path, "wb") as f:
        f.write(file_content)

    with open(os.path.join(UPLOAD_DIR, file.filename), "wb") as f:
        f.write(file_content)

    # Count pages
    try:
        reader = PdfReader(pdf_path)
        num_pages = len(reader.pages)
    except:
        num_pages = 1

    print(f"📄 Pages: {num_pages}")

    # ══════════════════════════════════════════════════════════
    # SMALL FILE: Process entirely
    # ══════════════════════════════════════════════════════════
    if file_size_kb <= 100 or num_pages == 1:
        print("🎵 Small file — processing directly")

        loop = asyncio.get_event_loop()
        notes, wav_path = await loop.run_in_executor(
            _executor, process_pdf_to_notes_and_audio, pdf_path, job_dir, job_id
        )

        if notes is None:
            raise HTTPException(status_code=500, detail="Could not recognize music in this PDF")

        audio_b64 = read_wav_as_base64(wav_path)
        print(f"✅ DONE: {len(notes)} notes | audio={'yes' if audio_b64 else 'no'} | {time.time() - start_time:.1f}s")

        return {
            "notes": notes,
            "audioUrl": f"audio/{job_id}/{job_id}.wav",
            "audioBase64": audio_b64,
            "jobId": job_id,
            "totalPages": 1,
            "isMultiPage": False
        }

    # ══════════════════════════════════════════════════════════
    # LARGE FILE: Split pages, process page 1 only
    # ══════════════════════════════════════════════════════════
    print(f"📑 Large file — splitting {num_pages} pages")

    for i, page in enumerate(reader.pages):
        writer = PdfWriter()
        writer.add_page(page)
        page_path = os.path.join(job_dir, f"page_{i+1}.pdf")
        with open(page_path, "wb") as f:
            writer.write(f)

    # Process page 1
    print("🎵 Processing page 1...")
    page1_dir = os.path.join(job_dir, "page_1")
    loop = asyncio.get_event_loop()
    notes, wav_path = await loop.run_in_executor(
        _executor, process_pdf_to_notes_and_audio,
        os.path.join(job_dir, "page_1.pdf"), page1_dir, "page_1"
    )

    if notes is None:
        raise HTTPException(status_code=500, detail="Could not recognize music in page 1")

    audio_b64 = read_wav_as_base64(wav_path)
    print(f"✅ Page 1: {len(notes)} notes | audio={'yes' if audio_b64 else 'no'} | {time.time() - start_time:.1f}s")

    return {
        "notes": notes,
        "audioUrl": f"audio/{job_id}/page_1.wav",
        "audioBase64": audio_b64,
        "jobId": job_id,
        "totalPages": num_pages,
        "isMultiPage": True
    }


@app.post("/process-page/")
async def process_page(job_id: str, page_num: int):
    """
    Start processing a page in the background.
    Returns immediately so ngrok doesn't timeout.
    Flutter polls /page-status/ to check when it's done.
    """
    print(f"\n📄 Starting background processing: page {page_num} for {job_id}")

    job_dir = os.path.join(OUTPUT_DIR, job_id)
    page_pdf = os.path.join(job_dir, f"page_{page_num}.pdf")

    if not os.path.exists(page_pdf):
        raise HTTPException(status_code=404, detail=f"Page {page_num} not found")

    task_key = f"{job_id}_page_{page_num}"

    # Already processing or done?
    if task_key in _page_tasks:
        status = _page_tasks[task_key]["status"]
        if status == "processing":
            return {"status": "processing", "pageNum": page_num}
        elif status == "done":
            return _page_tasks[task_key]["result"]

    # Mark as processing
    _page_tasks[task_key] = {"status": "processing"}

    # Run in background thread — returns immediately
    def _bg_process():
        try:
            page_dir = os.path.join(job_dir, f"page_{page_num}")
            notes, wav_path = process_pdf_to_notes_and_audio(
                page_pdf, page_dir, f"page_{page_num}"
            )

            if notes is None:
                _page_tasks[task_key] = {
                    "status": "error",
                    "error": f"Could not process page {page_num}"
                }
                print(f"❌ Page {page_num}: processing failed")
                return

            # Skip base64 for page audio — Flutter downloads via /audio/ endpoint
            # This avoids memory issues and ngrok connection drops for large files
            wav_size = os.path.getsize(wav_path) if wav_path and os.path.exists(wav_path) else 0
            audio_b64 = None
            if wav_path and wav_size > 0 and wav_size < 2_000_000:  # Only base64 for < 2MB
                audio_b64 = read_wav_as_base64(wav_path)

            result = {
                "status": "done",
                "notes": notes,
                "audioUrl": f"audio/{job_id}/page_{page_num}.wav",
                "audioBase64": audio_b64,
                "pageNum": page_num,
            }
            _page_tasks[task_key] = {"status": "done", "result": result}
            print(f"✅ Page {page_num}: {len(notes)} notes | wav={wav_size}B | b64={'yes' if audio_b64 else 'skip'} (background complete)")

        except Exception as e:
            _page_tasks[task_key] = {"status": "error", "error": str(e)}
            print(f"❌ Page {page_num} background error: {e}")

    _executor.submit(_bg_process)

    return {"status": "processing", "pageNum": page_num}


@app.get("/page-status/")
async def page_status(job_id: str, page_num: int):
    """
    Poll this endpoint to check if a page is done processing.
    Returns status: 'processing', 'done', or 'error'.
    When 'done', includes notes + audioUrl.
    """
    task_key = f"{job_id}_page_{page_num}"

    if task_key not in _page_tasks:
        raise HTTPException(status_code=404, detail=f"No task found for page {page_num}")

    task = _page_tasks[task_key]

    if task["status"] == "processing":
        return {"status": "processing", "pageNum": page_num}
    elif task["status"] == "done":
        return task["result"]
    else:
        raise HTTPException(status_code=500, detail=task.get("error", "Unknown error"))


@app.get("/health")
async def health():
    """Health check endpoint"""
    return {"status": "ok"}

