flowchart TD

    A([🚀 App Launch / Login]) --> B[🏠 Home / Dashboard]
    B --> C[📂 Pick PDF\nUser selects PDF from device]
    C --> D[👀 Preview PDF]

    D -->|User confirms| E[⚙️ Process Sheet]
    E --> F[📤 Upload PDF over HTTPS]

    F --> G[["🖥️ Backend Processing\nFastAPI server via ngrok"]]

    G --> H1["🎼 Optical Music Recognition\nAudiveris runs\nPDF → MXL"]
    G --> H2["🎵 Convert MusicXML → MIDI\nmusic21 library"]
    G --> H3["🔊 Synthesize MIDI → WAV\nFluidSynth"]

    H1 --> I1["📝 Extract Note Events\npitch, start, duration"]
    H2 --> I1
    H3 --> I2["🎧 Produce WAV File\nor provide URL"]

    I1 --> J["📦 Backend returns JSON\n{ notes: [...], audioUrl, jobId, ... }"]
    I2 --> J

    J --> K["📱 App receives result\nApiService"]

    K --> L["🗺️ Map MIDI → Guitar Positions\nMidiMapper converts pitch → string + fret\nNotes outside guitar range are skipped"]

    L --> M[["🎮 Practice Page Opens\n• Audio loaded from base64 or downloaded\n• Play controls visible\n• Sync calibration ±500ms\n• Mode: Watch or Practice"]]

    M --> N["▶️ Play Audio + Animate Fretboard\n• AudioPlayer → timing source\n• CustomPainter scrolls notes right → left\n• Playhead fixed at 30% from left\n• Notes color-coded per string"]

    N --> O{"🎸 Practice Mode?"}

    O -->|Watch Mode| O1["👁️ Passive Animation\nUser watches fretboard scroll\nNo mic input"]

    O -->|Practice Mode| O2["🎤 Mic Active\nAudioRecorderService records PCM\nPitchDetector runs autocorrelation\n75Hz – 1400Hz guitar range"]

    O2 --> O3["📊 Compare Notes\nSung/played note vs expected note\nperfect / good / acceptable / close / wrong"]
    O3 --> O4["💬 Visual Feedback\n_buildFeedbackBar displays result"]

    O1 --> P
    O4 --> P

    N --> MP{"📄 Multi-page File?"}
    MP -->|Yes| MP1["⏳ Background Page Processing\nPOST /process-page async\nFlutter polls GET /page-status\nRetry up to 3x on failure"]
    MP1 --> MP2["🔗 Pages combined into full track\nGET /combine-audio\nPage offsets stitched into timeline"]
    MP2 --> P
    MP -->|No| P

    P[["📈 Results / Feedback\n• Visual progress per note\n• Per-note accuracy feedback"]]

    P --> Q{"🔁 Next Action?"}

    Q -->|Replay| R1["⏮ Seek to 0\nRestart playback"]
    Q -->|Adjust Sync| R2["🎚 Sync Slider ±500ms\n_syncOffsetMs calibration"]
    Q -->|Jump Page| R3["📄 jumpToPage N\nNavigate to selected page"]
    Q -->|Re-upload| R4["📂 Return to Pick PDF"]

    R1 --> N
    R2 --> N
    R3 --> N
    R4 --> C

    %% Background async note (dashed style via subgraph)
    subgraph ASYNC ["⏳ Background / Async Work"]
        MP1
        MP2
    end

    %% STYLES
    classDef launch fill:#1a1a2e,color:#e0e0ff,stroke:#4a90d9,stroke-width:2px
    classDef userAction fill:#1b3a2d,color:#d0ffd0,stroke:#27ae60,stroke-width:2px
    classDef process fill:#3a2a1a,color:#ffe0c0,stroke:#e67e22,stroke-width:2px
    classDef backend fill:#2a1a3a,color:#f0d0ff,stroke:#9b59b6,stroke-width:2px
    classDef pipeline fill:#2a1a1a,color:#ffd0d0,stroke:#e74c3c,stroke-width:2px
    classDef flutter fill:#1a2a3a,color:#d0e8ff,stroke:#2980b9,stroke-width:2px
    classDef practice fill:#1a1a3a,color:#d0d0ff,stroke:#3498db,stroke-width:2px
    classDef feedback fill:#2a2a1a,color:#ffffd0,stroke:#f1c40f,stroke-width:2px
    classDef decision fill:#2a2a2a,color:#ffffff,stroke:#888888,stroke-width:2px
    classDef async fill:#1a2a1a,color:#c0ffc0,stroke:#2ecc71,stroke-width:1px,stroke-dasharray:5 5

    class A launch
    class B,C,D userAction
    class E,F process
    class G backend
    class H1,H2,H3 pipeline
    class I1,I2 pipeline
    class J backend
    class K,L flutter
    class M,N practice
    class O,MP decision
    class O1,O2,O3,O4 practice
    class P,Q feedback
    class R1,R2,R3,R4 userAction
    class MP1,MP2 async