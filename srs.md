Software Requirements Specification
for

Guitar Tab Tutor
Version 1.0 approved

Prepared by Safal T

Personal / Academic Project

June 2025

Table of Contents
Table of Contents ................................................................................................................... ii
Revision History ..................................................................................................................... ii

Introduction ........................................................................................................................ 1
1.1 Purpose ......................................................................................................................... 1
1.2 Document Conventions ................................................................................................. 1
1.3 Intended Audience and Reading Suggestions ................................................................ 1
1.4 Product Scope ............................................................................................................... 1
1.5 References ..................................................................................................................... 2
Overall Description ............................................................................................................ 2
2.1 Product Perspective ....................................................................................................... 2
2.2 Product Functions .......................................................................................................... 3
2.3 User Classes and Characteristics ................................................................................... 3
2.4 Operating Environment ................................................................................................. 4
2.5 Design and Implementation Constraints ........................................................................ 4
2.6 User Documentation ..................................................................................................... 5
2.7 Assumptions and Dependencies .................................................................................... 5
External Interface Requirements ....................................................................................... 5
3.1 User Interfaces .............................................................................................................. 5
3.2 Hardware Interfaces ....................................................................................................... 6
3.3 Software Interfaces ....................................................................................................... 6
3.4 Communications Interfaces ........................................................................................... 7
System Features ................................................................................................................. 8
4.1 User Authentication ...................................................................................................... 8
4.2 PDF Music Sheet Selection ........................................................................................... 9
4.3 PDF Preview ................................................................................................................ 10
4.4 Music Sheet Processing (OMR Pipeline) ..................................................................... 11
4.5 MIDI-to-Guitar Fretboard Mapping ............................................................................. 13
4.6 Interactive Fretboard Practice (Watch Mode) ............................................................... 14
4.7 Real-Time Pitch Detection (Practice Mode) ................................................................ 15
4.8 Multi-Page Background Processing ............................................................................. 17
4.9 Audio Playback and Synchronization ........................................................................... 18
4.10 Server Configuration ................................................................................................. 19
Other Nonfunctional Requirements ................................................................................. 20
5.1 Performance Requirements .......................................................................................... 20
5.2 Safety Requirements .................................................................................................... 21
5.3 Security Requirements ................................................................................................. 21
5.4 Software Quality Attributes ......................................................................................... 21
5.5 Business Rules ............................................................................................................. 22
Other Requirements ......................................................................................................... 22
Appendix A: Glossary ........................................................................................................... 22
Appendix B: Analysis Models .............................................................................................. 23
Appendix C: To Be Determined List .................................................................................... 24
Revision History
Name	Date	Reason For Changes	Version
Safal T	June 2025	Initial creation	1.0
Software Requirements Specification for Guitar Tab Tutor — Page 1

1. Introduction
1.1 Purpose
This document specifies the software requirements for Guitar Tab Tutor, version 1.0. Guitar Tab Tutor is a cross-platform mobile application that allows guitar learners to upload sheet music in PDF format, automatically converts it into guitar tablature using Optical Music Recognition (OMR), and provides an interactive, animated fretboard practice environment with real-time pitch detection feedback. This SRS covers the complete system, including the Flutter mobile front-end, the FastAPI back-end server, and the OMR processing pipeline.

1.2 Document Conventions
This SRS follows the IEEE 830 / Karl Wiegers SRS template structure. The following conventions are used throughout:

Bold text indicates key terms, product names, or emphasis.
Monospace text indicates code elements, file names, class names, function names, or technical identifiers.
Requirement identifiers follow the format REQ-X-Y where X is the feature section number and Y is the sequential requirement number within that feature.
Unless otherwise stated, priorities assigned to higher-level features are inherited by their detailed functional requirements.
Priority levels are designated as High, Medium, or Low.
1.3 Intended Audience and Reading Suggestions
This document is intended for the following audiences:

Developers: Should read the entire document, focusing on Sections 3 (External Interface Requirements), 4 (System Features), and 5 (Nonfunctional Requirements) for implementation guidance.
Project Evaluators / Academic Supervisors: Should begin with Section 1.4 (Product Scope) and Section 2 (Overall Description) for a high-level understanding, then review Section 4 for feature completeness.
Testers: Should focus on Section 4 (System Features), particularly the Stimulus/Response Sequences and Functional Requirements subsections, to derive test cases.
End Users / Guitar Learners: Should read Section 1.4 (Product Scope) and Section 2.2 (Product Functions) for a summary of capabilities.
It is recommended to read the document sequentially from Section 1 through Section 2 for context, then proceed to Section 4 for detailed feature specifications.

1.4 Product Scope
Guitar Tab Tutor is a mobile application designed to bridge the gap between traditional sheet music and guitar tablature for beginner-to-intermediate guitar learners. The application enables users to:

Upload any guitar sheet music in PDF format from their device.
Automatically process the sheet music through an Optical Music Recognition pipeline that converts standard musical notation into machine-readable note events.
Map recognized musical notes to guitar string and fret positions using standard EADGBE tuning.
View and practice the music on an animated, scrolling fretboard highway where notes approach a fixed playhead in real time, synchronized with synthesized audio playback.
Practice in two modes: Watch Mode (passive observation with audio) and Practice Mode (active playing with microphone-based pitch detection and accuracy feedback).
Handle multi-page sheet music with background page processing and seamless audio stitching.
The primary objective is to eliminate the need for manual tablature transcription and provide an engaging, interactive practice tool that accelerates guitar learning. The application targets individual guitar learners and music students who have access to sheet music in PDF format but prefer tablature-based learning.

1.5 References
#	Title	Author / Source	Version	Date
1	Flutter SDK Documentation	Google	3.x	2024
2	Firebase Authentication Documentation	Google Firebase	Latest	2024
3	Audiveris OMR Software Documentation	Audiveris.org	5.x	2024
4	music21 Library Documentation	MIT / Cuthbert	9.x	2024
5	mido — MIDI Objects for Python	Ole Martin Bjørndalen	1.3.x	2024
6	FluidSynth Software Synthesizer	fluidsynth.org	2.x	2024
7	FastAPI Framework Documentation	Sebastián Ramírez	0.100+	2024
8	IEEE 830-1998 Recommended Practice for SRS	IEEE	1998	1998
9	Karl Wiegers SRS Template	Karl E. Wiegers	1.0	1999
Software Requirements Specification for Guitar Tab Tutor — Page 2

2. Overall Description
2.1 Product Perspective
Guitar Tab Tutor is a new, self-contained product that combines several existing technologies into a unified system. It is not a replacement for any existing commercial product, but rather an original integration of the following components:

Mobile Front-End: A Flutter-based Android application providing the user interface, audio playback, pitch detection, and animated fretboard rendering.
Backend Server: A Python FastAPI server that receives PDF uploads and orchestrates the OMR processing pipeline.
OMR Engine: Audiveris, an external open-source Optical Music Recognition software that converts PDF sheet music images into MusicXML format.
Music Processing Libraries: music21 (MusicXML to MIDI conversion) and mido (MIDI parsing to extract note events).
Audio Synthesis: FluidSynth, an external software synthesizer that converts MIDI files into WAV audio using SoundFont instrument samples.
Secure Tunneling: Cloudflare Tunnel or ngrok for exposing the local backend server to the mobile application over HTTPS.
The system architecture follows a client-server model where the mobile app communicates with the backend via HTTPS REST API calls. The following diagram illustrates the major components:

text

┌──────────────┐    HTTPS     ┌──────────────┐     ┌─────────────┐
│ Flutter App  │ ──────────── │ Cloudflare / │ ──► │  FastAPI     │
│ (Android)    │              │ ngrok Tunnel │     │  Backend     │
└──────┬───────┘              └──────────────┘     └──────┬──────┘
       │                                                   │
       │ Local                                    ┌────────┼────────┐
       │                                          │        │        │
  ┌────┴─────┐                              ┌─────┴──┐ ┌───┴───┐ ┌─┴────────┐
  │Firebase  │                              │Audiveris│ │music21│ │FluidSynth│
  │Auth      │                              │OMR     │ │MIDI   │ │WAV Synth │
  └──────────┘                              └────────┘ └───────┘ └──────────┘
2.2 Product Functions
The major functions of Guitar Tab Tutor are summarized below:

User Authentication: Email and password-based registration and login via Firebase Authentication.
PDF Sheet Music Upload: Selection of PDF files from the device's local storage using a file picker.
PDF Preview: On-screen rendering and preview of the selected PDF before processing.
Optical Music Recognition: Automated conversion of PDF sheet music to MusicXML using Audiveris, then to MIDI using music21, and extraction of note events (pitch, start time, duration) using mido.
Audio Synthesis: Conversion of MIDI to WAV audio using FluidSynth with General MIDI SoundFont for playback.
MIDI-to-Guitar Mapping: Intelligent mapping of MIDI pitch values to guitar string and fret positions using standard EADGBE tuning with positional preference regions.
Animated Fretboard Highway: A scrolling, color-coded fretboard visualization using CustomPainter, synchronized with audio playback, showing notes approaching a fixed playhead.
Watch Mode: Passive playback mode where the user observes the animated fretboard with synchronized audio.
Practice Mode: Active mode where the microphone captures the user's playing, performs real-time pitch detection via autocorrelation, and provides visual feedback on accuracy (perfect, good, acceptable, close, wrong).
Multi-Page Processing: Background processing of subsequent pages for multi-page PDFs, with progressive loading and combined audio stitching.
Playback Controls: Play/pause, replay, tempo adjustment (0.25x–2.0x), sync calibration (±500ms), and page navigation.
Server Configuration: User-configurable backend URL for flexible deployment via Cloudflare Tunnel or ngrok.
2.3 User Classes and Characteristics
User Class	Description	Frequency of Use	Technical Expertise	Priority
Guitar Learner (Primary)	Beginner-to-intermediate guitar students who have PDF sheet music and wish to practice using tablature on a visual fretboard. They are familiar with basic smartphone operation but may have limited musical theory knowledge.	Daily to weekly practice sessions	Low to moderate (smartphone-literate)	Most Important
Music Teacher	Instructors who may use the app to demonstrate pieces to students or assign practice material. They have higher musical expertise and may use multi-page complex scores.	Weekly	Moderate to high	Important
Developer / Administrator	Individuals who deploy and maintain the backend server, configure tunneling, and troubleshoot processing issues.	As needed for maintenance	High (technical)	Supporting
2.4 Operating Environment
Mobile Client:

Platform: Android 6.0 (API level 23) and above.
Framework: Flutter SDK 3.x with Dart.
Orientation: Portrait mode for all screens except Practice Page (landscape).
Required Permissions: RECORD_AUDIO (for microphone-based pitch detection in Practice Mode), Internet access.
Hardware: Requires a device with a functional microphone, speaker or headphone output, and minimum 2 GB RAM.
Backend Server:

Operating System: Windows 10/11 (required for Audiveris .exe execution). Linux/macOS supported if Audiveris is available as JAR.
Runtime: Python 3.9+ with Uvicorn ASGI server.
Required Software:
Audiveris 5.x (installed at C:\Program Files\Audiveris\bin\Audiveris.exe or accessible via system PATH).
FluidSynth 2.x (must be on system PATH).
FluidR3_GM.sf2 SoundFont file (located in backend/ directory).
Network: Requires an active Cloudflare Tunnel or ngrok tunnel for HTTPS exposure to the mobile client, or direct LAN access for local development.
2.5 Design and Implementation Constraints
DC-1: The mobile application must be developed using the Flutter framework to enable potential cross-platform deployment (currently targeting Android).
DC-2: User authentication must use Firebase Authentication; no custom authentication backend shall be implemented.
DC-3: The OMR processing relies on Audiveris, which is an external Java-based application. Processing times are dependent on Audiveris performance and cannot be optimized within this project's scope.
DC-4: The backend server must run on a machine where Audiveris and FluidSynth are installed and accessible via command-line subprocess calls.
DC-5: The Cloudflare Tunnel or ngrok URL is dynamic and changes on each tunnel restart; the app must provide a mechanism for the user to update the server URL.
DC-6: Guitar mapping is limited to standard EADGBE tuning with a maximum of 12 frets. Alternate tunings are not supported in version 1.0.
DC-7: MIDI pitches outside the guitar range (below MIDI 40 / E2 or above MIDI 88 / E6) are silently skipped and not displayed on the fretboard.
DC-8: Real-time pitch detection uses an autocorrelation algorithm limited to the frequency range 75 Hz – 1400 Hz, covering the standard guitar range.
DC-9: The fretboard animation renders at the device's native frame rate (typically ~60 fps) using Flutter's Ticker mechanism.
2.6 User Documentation
The following user documentation components will be delivered:

In-App Guidance: Status messages and SnackBar notifications guide the user through each step (uploading, processing, errors, practice feedback).
Server Settings Help Text: The Server Settings page includes hint text showing the expected URL format (e.g., https://xxx-xxx.trycloudflare.com).
README.md: A project README file in the repository root providing setup instructions for both the Flutter app and the Python backend, including dependency installation steps.
Code Comments: Inline documentation within source code files for developer reference.
2.7 Assumptions and Dependencies
AS-1: It is assumed that the user has access to guitar sheet music in standard PDF format. Handwritten or photographed sheet music may not be reliably recognized by Audiveris.
AS-2: The backend server machine has a stable internet connection for tunnel-based access, or the mobile device and server are on the same local network.
AS-3: Audiveris is assumed to be correctly installed and licensed on the backend machine. OMR accuracy depends on the quality and complexity of the input sheet music.
AS-4: FluidSynth and the FluidR3_GM.sf2 SoundFont file are assumed to be present and functional on the backend machine.
AS-5: Firebase project configuration (google-services.json) is assumed to be correctly set up in the Flutter project.
AS-6: The mobile device's microphone is assumed to be functional and capable of capturing audio at 22050 Hz sample rate for pitch detection.
DEP-1: Firebase Authentication service (Google Cloud dependency).
DEP-2: Audiveris 5.x open-source OMR engine.
DEP-3: music21 Python library (MIT).
DEP-4: mido Python library for MIDI parsing.
DEP-5: FluidSynth software synthesizer.
DEP-6: Cloudflare Tunnel or ngrok for HTTPS tunneling.
DEP-7: Flutter packages: file_picker, flutter_pdfview, audioplayers, record, http, shared_preferences.
Software Requirements Specification for Guitar Tab Tutor — Page 5

3. External Interface Requirements
3.1 User Interfaces
The application consists of the following screens, each with specific UI characteristics:

UI-1: Login Page

Two text input fields: Email and Password (obscured).
A "Login" button with haptic and audio feedback on press.
A "Create an account" text button linking to the Signup Page.
Animated entry: FadeIn and SlideUp animations using AnimationController (800ms duration).
Color scheme: Dark background (#121212) with green (#4CAF50) accent buttons.
Error feedback: Red SnackBar (#E53935) displayed on authentication failure.
Success feedback: Haptic vibration and 880 Hz success tone on successful login.
UI-2: Signup Page

Two text input fields: Email and Password.
A "Create Account" button.
FadeTransition animation (600ms duration).
On success: navigates back to Login Page with success feedback.
UI-3: PDF Picker Page

AppBar titled "Pick Sheet Music" with a settings gear icon (⚙️) in the actions area.
Body displays a music note icon (64px, green), instructional text ("Upload your guitar sheet music", "Supported format: PDF"), and a "Pick PDF" button.
File picker dialog filters to .pdf extension only.
UI-4: PDF View Page

AppBar titled "Music Sheet".
Body renders the selected PDF using the PDFView widget for on-screen preview.
Bottom section contains a "Process Sheet" button.
During processing: a loading indicator and status messages ("Uploading…", "Processing music sheet… This may take 1–2 minutes") are displayed.
UI-5: Practice Page (Landscape)

Fullscreen landscape orientation.
Animated fretboard highway rendered via CustomPainter occupying the majority of the screen.
Top bar: feedback display area showing current note status, pitch detection results, and streak information.
Bottom controls bar: Play/Pause, Replay, Tempo slider, Sync calibration slider, Page navigation buttons (for multi-page scores), and mode toggle (Watch/Practice).
Countdown overlay: "3… 2… 1…" with elastic scale animation before playback begins.
Completion overlay: "Song Complete!" with note count, page count, Replay button, and Back button.
UI-6: Server Settings Page

TextField pre-filled with the current backend URL.
Hint text: https://xxx-xxx.trycloudflare.com.
"Test & Save" button that tests connectivity before saving.
Green SnackBar on successful connection; red SnackBar on failure.
Page Transition Animations:

Login → PDF Picker: fadeScale (scale 0.92→1.0, 500ms, easeOutCubic + fade).
Login → Signup: slideUp (offset 0,0.15→0,0, 400ms, easeOutCubic + fade).
PDF Picker → PDF View: slideLeft (offset 1,0→0,0, 350ms, easeOutCubic + fade).
PDF View → Practice: fadeScale.
All transitions include a haptic light feedback on animation start.
3.2 Hardware Interfaces
HW-1: Device Microphone

Used in Practice Mode for capturing the user's guitar playing.
Audio is recorded as PCM 16-bit, mono, at 22050 Hz sample rate via the record Flutter package.
The RECORD_AUDIO permission is declared in AndroidManifest.xml.
HW-2: Device Speaker / Audio Output

Used for playback of synthesized WAV audio during Watch Mode and as reference audio.
Audio is played using the audioplayers Flutter package with DeviceFileSource.
HW-3: Device Storage

PDF files are read from the device's local storage via FilePicker.
Temporary WAV audio files are stored in the app's temporary directory during practice sessions and deleted on disposal.
HW-4: Device Display

Portrait orientation (1080×1920 or equivalent) for authentication, PDF picking, and PDF preview screens.
Landscape orientation for the Practice Page fretboard highway rendering.
Hardware-accelerated rendering is enabled via android:hardwareAccelerated="true" in the Android manifest.
3.3 Software Interfaces
SI-1: Firebase Authentication

Name and Version: Firebase Auth for Flutter (firebase_auth package).
Purpose: User registration and login.
Data Items:
Input: Email (String), Password (String).
Output: UserCredential object on success; FirebaseAuthException on failure.
Communication: SDK handles HTTPS communication with Google's Firebase Auth servers.
SI-2: FastAPI Backend REST API

Name and Version: FastAPI 0.100+, running on Uvicorn ASGI server.
Purpose: Receives PDF uploads, orchestrates OMR processing, returns note data and audio.
Endpoints and Data:
Endpoint	Method	Input	Output
/health	GET	None	{"status": "ok"}
/process-sheet/	POST	Multipart PDF file	JSON: {notes, audioUrl, audioBase64, jobId, totalPages, isMultiPage}
/process-page/	POST	Query: job_id, page_num	{"status": "processing"}
/page-status/	GET	Query: job_id, page_num	JSON: {status, notes, audioUrl, audioBase64, pageNum}
/audio/{job_id}/{file_name}	GET	Path parameters	WAV file (FileResponse)
/combine-audio/	GET	Query: job_id	JSON: {offsets, audioUrl}
SI-3: Audiveris OMR Engine

Name and Version: Audiveris 5.x.
Purpose: Converts PDF sheet music images to MXL (compressed MusicXML) format.
Interface: Subprocess call — Audiveris.exe -batch -export -output {dir} {pdf}.
Data: Input: PDF file path. Output: .mxl file(s) in the specified output directory.
SI-4: music21 Library

Name and Version: music21 9.x (Python).
Purpose: Parses MusicXML and exports MIDI.
Interface: Python subprocess — python -c "from music21 import *; converter.parse('{xml}').write('midi', '{midi_path}')".
Data: Input: MusicXML .xml file path. Output: .mid MIDI file.
SI-5: mido Library

Name and Version: mido 1.3.x (Python).
Purpose: Parses MIDI files to extract individual note events with timing.
Interface: Python API — mido.MidiFile(midi_path).
Data: Input: .mid file. Output: List of note event dictionaries [{"pitch": int, "start": float, "duration": float}].
SI-6: FluidSynth Synthesizer

Name and Version: FluidSynth 2.x.
Purpose: Synthesizes MIDI into WAV audio using a SoundFont.
Interface: Subprocess call — fluidsynth -T wav -F {wav_path} {sf2_path} {midi_path}.
Data: Input: .mid file + FluidR3_GM.sf2 SoundFont. Output: .wav audio file.
SI-7: SharedPreferences

Name and Version: shared_preferences Flutter package.
Purpose: Persists the user-configured backend server URL locally on the device.
Data: Key-value pair — server_url: String.
3.4 Communications Interfaces
CI-1: HTTPS REST API Communication

The mobile application communicates with the FastAPI backend exclusively over HTTPS.
The backend is exposed to the internet via Cloudflare Tunnel or ngrok, which provides an HTTPS endpoint (e.g., https://xxx-xxx.trycloudflare.com) that proxies to the local server running on localhost:8000.
Protocol: HTTP/1.1 over TLS (HTTPS).
Data Format: JSON for API responses; Multipart form-data for PDF file uploads.
Timeout: The PDF processing POST request has a client-side timeout of 360 seconds (6 minutes) to accommodate large or complex sheet music.
Polling: For multi-page background processing, the client polls the /page-status/ endpoint every 5 seconds with a maximum polling duration of 5 minutes per page.
Error Handling: The client detects SocketException, HttpException, TimeoutException, and failed host lookups, displaying appropriate error messages to the user.
CI-2: Firebase SDK Communication

Firebase Authentication SDK handles all communication with Google's authentication servers over HTTPS.
No custom communication protocol is implemented; the SDK manages token refresh, session persistence, and error handling internally.
Software Requirements Specification for Guitar Tab Tutor — Page 8

4. System Features
4.1 User Authentication
4.1.1 Description and Priority
User Authentication enables users to register and log in using email and password credentials via Firebase Authentication. This is a High priority feature as it gates access to all other application functionality.

4.1.2 Stimulus/Response Sequences
Login Sequence:

User opens the app → Login Page is displayed with FadeIn/SlideUp animation.
User enters email and password → taps "Login" button.
System plays a tick sound (800 Hz, 30ms) and haptic feedback.
System displays loading indicator.
5a. On success: system plays success sound (880 Hz, 80ms), navigates to PDF Picker Page with fadeScale transition.
5b. On failure: system plays error sound (220 Hz, 120ms), displays red SnackBar with error message (e.g., "Wrong password", "User not found").
Signup Sequence:

User taps "Create an account" on Login Page → Signup Page appears with slideUp transition.
User enters email and password → taps "Create Account".
3a. On success: system plays success sound, navigates back to Login Page.
3b. On failure: system plays error sound, displays red SnackBar with error message.
4.1.3 Functional Requirements
REQ-1-1: The system shall provide a Login Page with email and password text input fields.

REQ-1-2: The system shall authenticate users using FirebaseAuth.signInWithEmailAndPassword() with trimmed email and password inputs.

REQ-1-3: On successful authentication, the system shall navigate to the PDF Picker Page using Navigator.pushAndRemoveUntil(), removing all previous routes from the navigation stack.

REQ-1-4: On authentication failure, the system shall display a red SnackBar containing the error message from the FirebaseAuthException.

REQ-1-5: The system shall provide a Signup Page accessible from the Login Page via a "Create an account" text button.

REQ-1-6: The Signup Page shall register new users using FirebaseAuth.createUserWithEmailAndPassword().

REQ-1-7: On successful registration, the system shall navigate back to the Login Page.

REQ-1-8: The system shall provide audio and haptic feedback for all button interactions: tick sound on press, success sound on successful operations, error sound on failures.

REQ-1-9: The Login Page shall display FadeIn and SlideUp entry animations using an AnimationController with 800ms duration.

4.2 PDF Music Sheet Selection
4.2.1 Description and Priority
This feature enables users to select a PDF file containing guitar sheet music from their device's storage. This is a High priority feature as it is the entry point for all music processing.

4.2.2 Stimulus/Response Sequences
User views the PDF Picker Page with instructions and a "Pick PDF" button.
User taps "Pick PDF" → system opens the device file picker filtered to .pdf files.
3a. User selects a PDF → system plays tick sound, navigates to PDF View Page with slideLeft transition.
3b. User cancels the file picker → system returns to PDF Picker Page with no action.
4.2.3 Functional Requirements
REQ-2-1: The system shall display a PDF Picker Page with a music note icon, instructional text ("Upload your guitar sheet music", "Supported format: PDF"), and a "Pick PDF" button.

REQ-2-2: The system shall use FilePicker.platform.pickFiles() with type: FileType.custom and allowedExtensions: ['pdf'] to filter file selection to PDF files only.

REQ-2-3: If the user selects a valid PDF file, the system shall navigate to the PDF View Page, passing the selected file's path.

REQ-2-4: If the user cancels the file picker or no file is selected (null result), the system shall remain on the PDF Picker Page without any error message.

REQ-2-5: The PDF Picker Page AppBar shall include a settings icon (⚙️) that navigates to the Server Settings Page when tapped.

4.3 PDF Preview
4.3.1 Description and Priority
This feature allows users to preview the selected PDF on-screen before initiating the processing pipeline. This is a Medium priority feature that provides user confirmation before a potentially long-running operation.

4.3.2 Stimulus/Response Sequences
PDF View Page loads → PDF is rendered on-screen using the PDFView widget.
User reviews the PDF → taps "Process Sheet" button.
System plays tick sound → displays "Uploading…" status → then updates to "Processing music sheet… This may take 1–2 minutes".
System sends the PDF to the backend for processing.
5a. On success with notes: navigates to Practice Page.
5b. On success with empty notes: displays orange SnackBar "No notes found".
5c. On connection error: displays red SnackBar "Cannot reach server. Please check your server URL."
5d. On other error: displays red SnackBar with the error message.
4.3.3 Functional Requirements
REQ-3-1: The system shall render the selected PDF file on-screen using the flutter_pdfview package's PDFView widget.

REQ-3-2: The system shall display a "Process Sheet" button at the bottom of the PDF View Page.

REQ-3-3: When "Process Sheet" is tapped, the system shall set _processing = true and display progressive status messages: first "Uploading…", then after 200ms "Processing music sheet… This may take 1–2 minutes".

REQ-3-4: The system shall call ApiService.processSheet(File(pdfPath)) to upload and process the PDF.

REQ-3-5: If the processing result contains notes (result.notes.isNotEmpty), the system shall navigate to the Practice Page via Navigator.pushReplacement() with fadeScale animation, passing the notes, audioUrl, audioBase64, jobId, totalPages, and isMultiPage parameters.

REQ-3-6: If the processing result contains no notes (result.notes.isEmpty), the system shall display an orange SnackBar with the message "No notes found in this sheet".

REQ-3-7: If a network-related exception occurs (SocketException, Failed host lookup, Connection refused, timed out), the system shall display a red SnackBar with the message "Cannot reach the server. Please update your server URL in settings." with a duration of 6 seconds.

REQ-3-8: During processing, the "Process Sheet" button shall be disabled and a loading indicator shall be displayed.

4.4 Music Sheet Processing (OMR Pipeline)
4.4.1 Description and Priority
This is the core backend feature that converts a PDF music sheet into structured note events and synthesized audio. The pipeline uses Optical Music Recognition (Audiveris), music format conversion (music21), MIDI parsing (mido), and audio synthesis (FluidSynth). This is a High priority feature — without it, the application has no functional value.

4.4.2 Stimulus/Response Sequences
Backend receives a POST request to /process-sheet/ with a multipart PDF file.
Backend generates a unique job_id (UUID4) and saves the PDF to outputs/{job_id}/.
Backend reads the PDF to determine number of pages.
4a. If small file (≤100KB) or single page: processes the full PDF directly.
4b. If large file (>100KB) and multi-page: splits into individual page PDFs and processes only page 1 initially.
For each PDF processed through the pipeline:
Step 1: Audiveris converts PDF → MXL (timeout: 300s).
Step 2: MXL is unzipped → MusicXML (.xml) extracted.
Step 3: music21 converts MusicXML → MIDI (timeout: 120s).
Step 4: mido parses MIDI → list of note events [{pitch, start, duration}].
Step 5: FluidSynth converts MIDI → WAV audio (timeout: 120s).
Step 6: If WAV < 2MB, encode to Base64 for inline delivery.
Backend returns JSON response with notes, audio URL, optional Base64 audio, job ID, total pages, and multi-page flag.
4.4.3 Functional Requirements
REQ-4-1: The backend shall accept PDF file uploads via POST /process-sheet/ as multipart form data.

REQ-4-2: The backend shall generate a unique job_id using uuid.uuid4() for each upload and create a directory outputs/{job_id}/ to store all processing artifacts.

REQ-4-3: The backend shall use PyPDF2.PdfReader to count the number of pages in the uploaded PDF.

REQ-4-4: For files ≤100KB or single-page files, the backend shall process the entire PDF through the OMR pipeline in a single operation.

REQ-4-5: For files >100KB with multiple pages, the backend shall split the PDF into individual page files (page_1.pdf, page_2.pdf, …, page_N.pdf) using PyPDF2.PdfWriter and process only page 1 immediately, deferring remaining pages to the background processing endpoint.

REQ-4-6: The OMR pipeline shall execute Audiveris via subprocess with the command Audiveris.exe -batch -export -output {dir} {pdf} and a timeout of 300 seconds, polling process completion every 2 seconds.

REQ-4-7: The pipeline shall extract MusicXML from the resulting .mxl archive using zipfile.ZipFile.extractall(), and locate the MusicXML file by searching for .xml files while excluding container.xml and files within META-INF/.

REQ-4-8: The pipeline shall convert MusicXML to MIDI using music21 via a subprocess call with a timeout of 120 seconds.

REQ-4-9: The pipeline shall parse the MIDI file using the mido library, tracking tempo changes and converting tick deltas to seconds using mido.tick2second(). It shall pair note_on and note_off messages to produce a list of note events, each containing pitch (int), start (float, seconds), and duration (float, seconds). The minimum duration shall be clamped to 0.05 seconds. Notes shall be sorted by start time.

REQ-4-10: The pipeline shall synthesize the MIDI file to WAV audio using FluidSynth via the command fluidsynth -T wav -F {wav_path} {sf2_path} {midi_path} with a timeout of 120 seconds and using the FluidR3_GM.sf2 SoundFont.

REQ-4-11: If the WAV file exists and its size exceeds 1000 bytes, the backend shall encode it to Base64 for files under 2MB. For files 2MB or larger, the Base64 field shall be null and the client shall download the audio via the /audio/ endpoint.

REQ-4-12: The backend shall return a JSON response containing: notes (list of note event objects), audioUrl (string path to audio file), audioBase64 (Base64 string or null), jobId (UUID string), totalPages (integer), and isMultiPage (boolean).

REQ-4-13: If any step in the pipeline fails (no MXL found, no XML found, no MIDI produced, no notes extracted), the pipeline function shall return None for the failed outputs and the endpoint shall return an appropriate error or empty notes list.

REQ-4-14: All pipeline processing shall be executed in a ThreadPoolExecutor via asyncio.get_event_loop().run_in_executor() to prevent blocking the FastAPI event loop.

4.5 MIDI-to-Guitar Fretboard Mapping
4.5.1 Description and Priority
This feature maps MIDI pitch values from the OMR output to specific guitar string and fret positions using standard EADGBE tuning. This is a High priority feature as it determines the correctness of the tablature display.

4.5.2 Stimulus/Response Sequences
ApiService._parseNotes() receives a list of raw note dictionaries from the backend JSON response.
For each note, the MIDI pitch value is passed to MidiMapper.toStringFret(pitch).
3a. If the pitch is within guitar range (MIDI 40–88): the mapper returns a (stringIndex, fret) tuple, and a NoteEvent object is created with converted timing (seconds → milliseconds).
3b. If the pitch is outside guitar range: the mapper returns null, and the note is silently skipped.
4.5.3 Functional Requirements
REQ-5-1: The MidiMapper class shall define standard guitar tuning as six open-string MIDI values: string 0 = e (MIDI 64), string 1 = B (MIDI 59), string 2 = G (MIDI 55), string 3 = D (MIDI 50), string 4 = A (MIDI 45), string 5 = E (MIDI 40).

REQ-5-2: The mapper shall use positional preference regions to select the most natural string for each pitch:

MIDI ≥ 64: prefer strings [0, 1] (e, B).
MIDI 55–63: prefer strings [1, 2, 0] (B, G, e).
MIDI 50–54: prefer strings [2, 3, 1] (G, D, B).
MIDI 45–49: prefer strings [3, 4, 2] (D, A, G).
MIDI 40–44: prefer strings [4, 5, 3] (A, E, D).
REQ-5-3: For each preferred string, the mapper shall calculate fret = pitch - openStringMidi. If the fret value is between 0 and 12 (inclusive), it is a valid candidate. The mapper shall select the candidate with the lowest fret value.

REQ-5-4: If no valid position is found in the preferred strings, the mapper shall fall back to trying all six strings and select the lowest valid fret ≤ 12.

REQ-5-5: For MIDI pitch values below 40 or above 88, the mapper shall return null, and the calling code shall skip the note entirely without error.

REQ-5-6: The _parseNotes function shall convert start (seconds) to startMs (milliseconds) and duration (seconds) to durationMs (milliseconds) by multiplying by 1000.

REQ-5-7: Each parsed note shall be encapsulated in a NoteEvent object containing: pitch (original MIDI), startMs, durationMs, stringIndex, and fret.

4.6 Interactive Fretboard Practice (Watch Mode)
4.6.1 Description and Priority
This feature provides an animated, scrolling fretboard highway visualization synchronized with audio playback. Notes scroll from right to left, approaching a fixed playhead, while synthesized audio plays. This is a High priority feature as it is the primary user-facing practice interface.

4.6.2 Stimulus/Response Sequences
Practice Page opens → orientation switches to landscape → audio is loaded (from Base64 or downloaded).
A 3-2-1 countdown is displayed with elastic scale animation.
Audio playback begins → AudioPlayer.resume().
A Ticker fires every frame (~60 fps), reading the audio player's position and updating _songPosMs.
FretboardHighwayPainter repaints: notes scroll right-to-left at 180 pixels/second; the playhead is fixed at 30% from the left edge of the fretboard.
Active notes (playhead within note bounds) display with a glow effect.
When audio completes: ticker stops, a completion overlay is displayed.
4.6.3 Functional Requirements
REQ-6-1: Upon entering the Practice Page, the system shall switch the device orientation to landscape (landscapeLeft and landscapeRight).

REQ-6-2: The system shall load audio from the backend response: if audioBase64 is non-null and non-empty, it shall be Base64-decoded and saved as a temporary .wav file. If audioBase64 is null, the system shall download the WAV file from the audioUrl endpoint via HTTP GET with a 180-second timeout and up to 3 retries with increasing delay (3×i seconds). The downloaded file shall be validated by checking for the RIFF header and a minimum size of 1000 bytes.

REQ-6-3: Before playback begins, the system shall display a countdown overlay ("3… 2… 1…") using a Timer.periodic with 1-second intervals and a TweenAnimationBuilder with Curves.elasticOut scaling animation.

REQ-6-4: The FretboardHighwayPainter (CustomPainter) shall render the following layers in order:

Background fill (#0D0D1A).
Fretboard wood panel (#2A1F0F, rounded rectangle).
Nut line (cream #F5E6C8, stroke width 4).
12 fret lines (brown #8B7355, stroke width 1.5).
Fret number labels (1–12, grey, below the fretboard).
6 guitar strings (gold #D4A84B, with thickness increasing for bass strings: 0.9 + stringIndex × 0.3).
String labels (e, B, G, D, A, E) color-coded on the left side.
Scrolling note boxes.
Playhead line (blue #2196F3, stroke 3, with glow blur of radius 6 at 30% opacity).
Active string indicator (white dot with shadow at playhead × active string intersection).
REQ-6-5: Note boxes shall be positioned using the formula: noteScreenX = playheadX + ((note.startMs - songPosMs) / 1000) × 180. Note width shall be (note.durationMs / 1000) × 180 pixels. Note Y position shall be boardTop + stringIndex × stringGap. Notes shall be skipped if their screen X position is more than 50 pixels beyond the right edge or more than 50 pixels beyond the left edge of the fretboard.

REQ-6-6: Each guitar string shall have a distinct color for its note boxes: string 0 (e) = Red #E53935, string 1 (B) = Orange #FB8C00, string 2 (G) = Yellow #FFD600, string 3 (D) = Green #43A047, string 4 (A) = Blue #1E88E5, string 5 (E) = Purple #8E24AA.

REQ-6-7: Active notes (where the playhead X falls within [noteScreenX, noteScreenX + noteWidth]) shall be rendered at full opacity with a glow blur effect (radius 12) underneath. Inactive notes shall be rendered at 75% opacity without the glow.

REQ-6-8: Each note box shall display the fret number as a label inside the box. Fret 0 (open string) shall be displayed as "O".

REQ-6-9: The playhead shall be fixed at 30% from the left edge of the fretboard area (playheadX = boardLeft + boardWidth × 0.3).

REQ-6-10: The painter's shouldRepaint() method shall return true whenever songPositionMs changes, ensuring continuous animation during playback.

REQ-6-11: Audio position shall be tracked via AudioPlayer.onPositionChanged stream. The effective song position shall be calculated as: _songPosMs = _audioPosMs + clock.elapsedMilliseconds × playbackRate + _syncOffsetMs.

4.7 Real-Time Pitch Detection (Practice Mode)
4.7.1 Description and Priority
This feature enables active practice by capturing the user's guitar playing through the device microphone, detecting the pitch of the played notes using an autocorrelation algorithm, and providing visual feedback on accuracy compared to the expected note. This is a High priority feature as it differentiates the app from a passive video player.

4.7.2 Stimulus/Response Sequences
User taps the "Practice" button → system requests microphone permission.
2a. Permission denied: orange SnackBar "Mic permission needed".
2b. Permission granted: current playback pauses, mode switches to Practice, fretboard shows the first note, microphone recording begins.
User plays a note on guitar → microphone captures PCM audio → PitchDetector analyzes the audio chunk.
4a. If pitch matches expected note (within tolerance): green/positive feedback displayed, note advances after 300ms.
4b. If pitch is close but not matching: amber feedback displayed, user retries.
4c. If pitch is wrong: red feedback displayed, retry button shown.
Process repeats for each note until all notes are completed.
4.7.3 Functional Requirements
REQ-7-1: The system shall initialize AudioRecorderService and request RECORD_AUDIO permission when the user activates Practice Mode.

REQ-7-2: If microphone permission is denied, the system shall display an orange SnackBar with the message "Microphone permission is needed for practice mode" and shall not enter Practice Mode.

REQ-7-3: The microphone shall record audio with the following configuration: PCM 16-bit encoding, mono channel, 22050 Hz sample rate. Audio data shall be streamed to the _processAudioChunk callback function.

REQ-7-4: The _processAudioChunk function shall enforce a debounce interval of 150 milliseconds between successive pitch detection analyses.

REQ-7-5: The PitchDetector.detectPitchDetailed() function shall:

Convert raw PCM bytes to float samples in the range [-1.0, 1.0].
Calculate the RMS (Root Mean Square) energy level. If RMS < 0.008, return null (signal too quiet).
Perform normalized autocorrelation analysis over the frequency range 75 Hz to 1400 Hz.
If the peak correlation confidence is below 0.15, return null (no clear pitch).
Convert the detected frequency to an exact MIDI note number using: exactMidi = 69 + 12 × log2(frequency / 440).
Round to the nearest integer MIDI note and calculate centsOffset = (exactMidi - roundedMidi) × 100.
Return a PitchResult containing: midiNote (int), frequency (double), confidence (double), and centsOffset (double).
REQ-7-6: The PitchDetector.matchQuality() function shall compare the detected MIDI note to the expected MIDI note and return one of the following quality grades:

Condition	Grade	Color	Behavior
Same note, ≤15 cents offset	perfect	Green #4CAF50	Advance to next note
Same note, ≤35 cents offset	good	Light Green #8BC34A	Advance to next note
Same note, ≤50 cents offset	acceptable	Yellow-Green #CDDC39	Advance to next note
1–2 semitones difference	close	Amber #FFC107	Retry
Detected < expected	tooLow	Orange #FF9800	Retry, show "Play higher"
Detected > expected	tooHigh	Deep Orange #FF5722	Retry, show "Play lower"
>2 semitones difference	wrong	Red #E53935	Retry, show "Check the fretboard"
REQ-7-7: When a note match quality results in shouldAdvance = true, the system shall:

Increment _correctCount and _consecutiveCorrect.
Check for streak milestones (at 3, 5, 10, 20, etc. consecutive correct notes) and play a streak chime.
After a 300ms delay, advance _currentNoteIndex to the next note and update _songPosMs to the next note's start time.
REQ-7-8: When a note match quality results in shouldRetry = true, the system shall:

Reset _consecutiveCorrect to 0 and _lastStreakMilestone to 0.
Mark _mistakeNoteIndex to the current note index.
Display a "Retry" button that, when tapped, repositions to the mistake note.
REQ-7-9: The Practice Mode feedback shall be displayed in a feedback bar widget (_buildFeedbackBar) showing the current feedback message, color, detected note name, expected note name, and streak count.

4.8 Multi-Page Background Processing
4.8.1 Description and Priority
For multi-page PDF sheet music, this feature processes pages 2 through N in the background while the user is already practicing with page 1. Pages are progressively loaded, and audio is combined into a seamless timeline. This is a Medium priority feature that enables support for longer musical pieces.

4.8.2 Stimulus/Response Sequences
After page 1 is loaded and the user begins practice, the system calls _loadNextPage().
System sends POST /process-page/?job_id=...&page_num=2 to the backend.
Backend spawns a background thread and returns immediately with {"status": "processing"}.
System polls GET /page-status/?job_id=...&page_num=2 every 5 seconds.
5a. When status is "done": system receives notes and audio for the page, saves audio locally, adds the page to the timeline, and attempts to build combined audio.
5b. When status is "error": system retries up to 3 times, then skips the page.
Process repeats for subsequent pages.
When all pages are loaded and combined audio is ready, the system performs a hot swap to a single combined audio player for seamless playback.
4.8.3 Functional Requirements
REQ-8-1: If isMultiPage is true and totalPages > 1, the system shall begin background processing of page 2 immediately after page 1's audio is loaded and the countdown begins.

REQ-8-2: The system shall call ApiService.startPageProcessing(jobId, pageNum) which sends POST /process-page/ with query parameters job_id and page_num. This endpoint shall return immediately with {"status": "processing"}.

REQ-8-3: The backend shall process the page in a background thread using ThreadPoolExecutor, storing the task status in an in-memory _page_tasks dictionary keyed by {job_id}_{page_num}.

REQ-8-4: The system shall poll ApiService.pollPageUntilDone(jobId, pageNum) which calls GET /page-status/ every 5 seconds for a maximum of 5 minutes (60 polls).

REQ-8-5: When a page's status becomes "done", the poll response shall include notes, audioUrl, audioBase64, and pageNum. The system shall save the audio locally and create a PageData object.

REQ-8-6: On page processing failure, the system shall retry the page up to 3 times with a 5-second delay between retries. After 3 failures, the page shall be skipped and the system shall proceed to the next page.

REQ-8-7: After each new page is loaded, the system shall call _rebuildTimeline() to reconstruct _allNotes (a flat list of all notes with global timestamps) and _pageOffsets (the starting millisecond of each page in the global timeline).

REQ-8-8: The system shall call _buildCombinedAudioLocally() to concatenate all page WAV files into a single combined.wav file, parsing RIFF/fmt/data chunks, trimming trailing silence from each page, and writing proper WAV headers. Page offset timestamps in milliseconds shall be stored.

REQ-8-9: When combined audio is ready and the user is currently playing, the system shall perform a hot swap (_hotSwapToCombined): pausing the current per-page player, creating a new single AudioPlayer for the combined WAV file, seeking to the current playback position, and resuming seamlessly.

REQ-8-10: The page navigation UI shall display page buttons: green for the active page, dim green for loaded pages, and an hourglass icon for pages still processing.

4.9 Audio Playback and Synchronization
4.9.1 Description and Priority
This feature manages audio playback using the audioplayers package, providing controls for play/pause, replay, tempo adjustment, and sync calibration. This is a High priority feature as audio synchronization is critical for the fretboard animation to be meaningful.

4.9.2 Stimulus/Response Sequences
User taps Play → AudioPlayer.resume(), ticker starts, clock resets and starts.
User taps Pause → AudioPlayer.pause(), ticker stops, clock stops.
User taps Replay → seek to position 0 (or combined audio start), restart.
User adjusts tempo slider → AudioPlayer.setPlaybackRate() with value 0.25x to 2.0x.
User adjusts sync slider → _syncOffsetMs updated (±500ms), immediately reflected in fretboard animation.
User taps a page button → _jumpToPage(): dispose old player, create new player for that page's audio, seek to the page's offset.
4.9.3 Functional Requirements
REQ-9-1: The system shall use the audioplayers package with DeviceFileSource to play locally-stored WAV files.

REQ-9-2: The Play/Pause button shall toggle between AudioPlayer.resume() and AudioPlayer.pause(), starting/stopping the Ticker and Stopwatch (_clock) accordingly.

REQ-9-3: The Replay function shall seek to position 0 (for combined audio) or call _jumpToPage(0) (for per-page audio) and restart playback from the beginning.

REQ-9-4: The tempo control shall provide a slider with range 0.25x to 2.0x in steps of 0.05. Tapping the center of the slider shall reset the tempo to 1.0x. The selected tempo shall be applied via AudioPlayer.setPlaybackRate().

REQ-9-5: The sync calibration control shall provide a slider with range -500ms to +500ms. The _syncOffsetMs value shall be added to the calculated song position (_songPosMs) to compensate for audio latency. A reset button shall set the value to 0ms.

REQ-9-6: When an audio player completes playback (onPlayerComplete), the system shall check: if in Watch Mode and combined audio is available, switch to combined audio at the next page offset. If the next page's audio is ready, auto-advance to that page. If no more pages exist, display the completion overlay.

REQ-9-7: The system shall support audio preloading: when a page is being played, the next page's audio player shall be pre-initialized with setSource() (without playing) so that transitions between pages are instantaneous.

REQ-9-8: Upon disposing the Practice Page, the system shall: restore orientation to portrait, cancel the countdown timer, cancel audio position and completion stream subscriptions, dispose the ticker, dispose the main audio player, dispose any preloaded audio player, dispose the recorder, and delete all temporary audio files.

4.10 Server Configuration
4.10.1 Description and Priority
This feature allows users to configure the backend server URL, supporting dynamic tunnel URLs from Cloudflare Tunnel or ngrok. This is a Medium priority feature that enables flexible deployment.

4.10.2 Stimulus/Response Sequences
User navigates to Server Settings Page from the PDF Picker Page.
User enters a new backend URL in the text field.
User taps "Test & Save".
System sends GET /health to the specified URL with a 5-second timeout.
5a. If the server responds with HTTP 200: the URL is saved to SharedPreferences, and a green SnackBar "Connected & saved" is displayed.
5b. If the server is unreachable: a red SnackBar "Cannot reach server" is displayed, and the URL is not saved.
4.10.3 Functional Requirements
REQ-10-1: The Server Settings Page shall display a TextField pre-filled with the current value of ApiService.baseUrl.

REQ-10-2: The "Test & Save" button shall call ApiService.testConnection(url) which sends an HTTP GET request to {url}/health with a timeout of 5 seconds.

REQ-10-3: If the health check response has status code 200, the system shall call ApiService.setBaseUrl(url) which saves the URL to SharedPreferences under a persistent key, and updates the in-memory baseUrl value.

REQ-10-4: On application launch, ApiService.init() shall load the previously saved server URL from SharedPreferences. If no URL is saved, a default URL shall be used.

REQ-10-5: The settings page shall display a hint text showing the expected URL format: https://xxx-xxx.trycloudflare.com.

Software Requirements Specification for Guitar Tab Tutor — Page 20

5. Other Nonfunctional Requirements
5.1 Performance Requirements
PERF-1: The fretboard highway animation shall render at a minimum of 30 frames per second (target: 60 fps, matching the device's native refresh rate) during audio playback in Watch Mode.

PERF-2: The FretboardHighwayPainter.shouldRepaint() method shall only trigger repaints when songPositionMs has changed, avoiding unnecessary rendering cycles when playback is paused.

PERF-3: Pitch detection in Practice Mode shall complete within the 150ms debounce window. The autocorrelation algorithm shall process a single audio chunk in under 50ms on a mid-range Android device.

PERF-4: The PDF upload and processing pipeline shall complete within 6 minutes (360-second client timeout) for a single-page PDF. Individual pipeline step timeouts are: Audiveris 300s, music21 120s, FluidSynth 120s.

PERF-5: Background page processing polls shall occur every 5 seconds with a maximum polling duration of 5 minutes per page, ensuring the client does not overwhelm the server.

PERF-6: Page navigation and audio source switching (including preloaded player swap) shall complete within 500ms to maintain a seamless user experience.

PERF-7: The application shall support PDF files up to 10MB and multi-page scores of up to 20 pages.

5.2 Safety Requirements
SAFE-1: Audio playback volume shall be controlled by the device's system volume settings. The application shall not programmatically increase volume beyond the user's set level.

SAFE-2: The application shall not produce sudden loud audio output that could damage hearing. Feedback tones are generated at low amplitude (0.3 amplitude factor) and short duration (30–120ms).

SAFE-3: Temporary audio files shall be deleted upon disposal of the Practice Page to prevent accumulation of storage usage.

5.3 Security Requirements
SEC-1: User authentication shall be handled exclusively by Firebase Authentication, which provides industry-standard password hashing, session management, and token-based authentication.

SEC-2: All communication between the mobile application and the backend server shall occur over HTTPS, enforced by the Cloudflare Tunnel or ngrok tunnel.

SEC-3: The backend server shall not store user credentials or personal information. PDF files are stored in the server's outputs/ directory for processing purposes only.

SEC-4: The Android manifest shall declare only the RECORD_AUDIO permission. The microphone shall only be activated when the user explicitly enters Practice Mode.

SEC-5: The backend server does not implement its own authentication layer. In a production deployment, API key or token-based authentication should be added (see Appendix C: TBD-1).

5.4 Software Quality Attributes
SQA-1 — Usability: The application shall provide a guided, linear flow (Login → Pick PDF → Preview → Practice) with clear status messages, animated transitions, and audio/haptic feedback at each step. A new user shall be able to complete the flow from login to practicing a single-page PDF within 5 minutes (excluding OMR processing time).

SQA-2 — Reliability: The OMR pipeline shall gracefully handle failures at each step (no MXL, no XML, no MIDI, no notes, no WAV), returning partial results or appropriate error messages rather than crashing. Multi-page processing shall retry failed pages up to 3 times before skipping.

SQA-3 — Maintainability: The codebase shall be organized into clear separation of concerns: screens/ for UI pages, services/ for business logic (ApiService, MidiMapper, PitchDetector, AppFeedbackService), widgets/ for reusable UI components (FretboardHighwayPainter), and models/ for data classes (NoteEvent).

SQA-4 — Portability: The Flutter front-end is inherently cross-platform. While version 1.0 targets Android, the codebase shall not include Android-specific code outside of the manifest configuration, enabling future iOS deployment.

SQA-5 — Testability: Each service class (MidiMapper, PitchDetector, ApiService) shall have clearly defined inputs and outputs that can be unit-tested independently.

SQA-6 — Robustness: The application shall handle network interruptions, invalid PDF files, server unavailability, and microphone permission denial gracefully, with user-facing error messages and no unhandled exceptions.

5.5 Business Rules
BR-1: Only authenticated users (via Firebase) shall have access to the PDF Picker Page and all subsequent features. Unauthenticated users shall only see the Login Page.

BR-2: The application supports only standard EADGBE guitar tuning. Alternate tunings are not supported in version 1.0.

BR-3: Only PDF files shall be accepted as input. Other file formats (images, MIDI, MusicXML) shall not be selectable through the file picker.

BR-4: The OMR processing is designed for printed/typeset sheet music. Handwritten scores are not guaranteed to produce accurate results.

BR-5: The practice feedback system does not record or persist user performance history. Each session is independent.

6. Other Requirements
OR-1 — Backend Deployment: The backend must be deployed on a machine with Audiveris, FluidSynth, FluidR3_GM.sf2, Python 3.9+, and all required Python packages installed. A Cloudflare Tunnel or ngrok tunnel must be configured and running to expose the server to the mobile app.

OR-2 — Storage Management: The backend outputs/ directory will accumulate processed files (PDFs, MXLs, XMLs, MIDIs, WAVs) over time. A periodic cleanup mechanism or disk space monitoring should be implemented for long-term deployment.

OR-3 — Concurrent Processing: The backend uses a ThreadPoolExecutor for parallel processing. The default thread pool size should be appropriate for the server hardware (e.g., 2–4 workers for a typical desktop machine).

OR-4 — Firebase Configuration: The Flutter project requires a valid google-services.json file for Android, configured with the appropriate Firebase project settings (Authentication enabled with Email/Password provider).

Appendix A: Glossary
Term	Definition
OMR	Optical Music Recognition — the process of converting images of musical notation into machine-readable formats.
MusicXML	An open, XML-based format for representing Western musical notation.
MXL	A compressed (ZIP) archive format containing MusicXML files.
MIDI	Musical Instrument Digital Interface — a protocol and file format for representing musical performance data (notes, timing, velocity).
MIDI Pitch	An integer value (0–127) representing a musical note. Middle C = 60.
WAV	Waveform Audio File Format — an uncompressed audio format.
SoundFont (SF2)	A file format containing sampled audio for synthesizing MIDI into audio.
FluidSynth	An open-source software synthesizer that renders MIDI to audio using SoundFonts.
Audiveris	An open-source OMR engine that converts scanned/PDF sheet music to MusicXML.
music21	A Python library for computer-aided musicology, used here for MusicXML to MIDI conversion.
mido	A Python library for reading, writing, and manipulating MIDI files.
FastAPI	A modern, high-performance Python web framework for building APIs.
Uvicorn	An ASGI server implementation for running FastAPI applications.
ngrok	A tool that creates secure tunnels from a public URL to a local server.
Cloudflare Tunnel	A service that exposes local servers to the internet via Cloudflare's network.
Fretboard Highway	The scrolling visual representation of the guitar fretboard where note boxes approach a fixed playhead.
Playhead	A fixed vertical line on the fretboard highway that represents the current playback position.
Autocorrelation	A signal processing technique used here for pitch detection by finding periodic patterns in audio signals.
Cents	A unit of measurement for musical intervals. 100 cents = 1 semitone.
Base64	A binary-to-text encoding scheme used to embed binary data (WAV audio) in JSON responses.
PCM	Pulse-Code Modulation — a standard format for representing digital audio samples.
RMS	Root Mean Square — a measure of the average energy level of an audio signal.
EADGBE	Standard guitar tuning, from the lowest (6th) to highest (1st) string.
NoteEvent	A data object representing a single musical note with pitch, start time, duration, string index, and fret.
PageData	A data object representing a single page's notes and audio within a multi-page score.
SheetProcessResult	A data object returned by ApiService.processSheet() containing parsed notes, audio data, and metadata.