# GUITAR TAB TUTOR
## Project Report Template

---

## COVER PAGE

CENTRE FOR COMPUTERS AND COMMUNICATION TECHNOLOGY
CHISOPANI, NAMCHI SIKKIM
(Department of Computer Science and Technology)
Approved by A.I.C.T.E. NBA accredited Program

---

## GUITAR TAB TUTOR

An Interactive Music Learning Platform

**Project Report Submitted In Partial Fulfillment of the Requirements for the Degree**

**Submitted by:**
[Group Member Names]

**Guided by:**
[Guide Name]

**Date of Submission:**
[Date]

---

## CERTIFICATE

This is to certify that the project report titled "GUITAR TAB TUTOR" is an authentic work carried out by the students at Centre for Computers and Communication Technology, Chisopani, Namchi, Sikkim under the guidance of [Guide Name].

The information contained in this report has not been submitted for any other degree or diploma.

---

## ACKNOWLEDGEMENT

We would like to express our gratitude to [Guide Name] for their valuable guidance and support throughout this project. We also thank the faculty and staff of the Centre for Computers and Communication Technology for providing the necessary resources and environment to complete this work successfully.

---

## SYNOPSIS

Guitar Tab Tutor is an interactive music learning application designed to help beginner guitar players learn visually using their own printed music sheets. The application combines optical music recognition, MIDI processing, and real-time audio synthesis with an animated fretboard visualization. Users upload PDF sheet music, which is processed by the backend to extract timed note events and generate synchronized audio. The Flutter mobile app then displays an animated fretboard highway synchronized with the audio playback, helping learners understand finger positions and timing. The system provides instant feedback on performance, helping users improve faster and build confidence in their playing.

---

## CONTENTS

1. INTRODUCTION
   1.1 Background
   1.2 Problem Statement
   1.3 Objectives
   1.4 Scope

2. SRS (SOFTWARE REQUIREMENTS SPECIFICATION)
   2.1 Functional Requirements
   2.2 Non-Functional Requirements
   2.3 System Architecture
   2.4 Use Cases

3. DESIGN AND DEVELOPMENT
   3.1 System Design
   3.2 Frontend Design
   3.3 Backend Design
   3.4 Database Design
   3.5 Algorithm and Logic

4. ESTIMATION AND COSTING
   4.1 Resource Estimation
   4.2 Cost Breakdown
   4.3 Actual Cost

5. IMPLEMENTATION AND APPLICATION
   5.1 Development Approach
   5.2 Technologies Used
   5.3 Key Implementation Details
   5.4 Applications and Benefits
   5.5 Institutional Relevance

6. CONCLUSION AND FUTURE DIRECTIONS
   6.1 Summary
   6.2 Achievements
   6.3 Future Enhancements

---

## CHAPTER 1: INTRODUCTION

### 1.1 Background

Traditional guitar learning relies heavily on sheet music notation and textual tab representations. Many beginners find it challenging to transition from visual notation to actual finger positioning on the fretboard. Digital learning platforms exist, but most restrict users to predefined lessons or limited song libraries rather than supporting practice with their own sheet music.

The intersection of music technology and digital learning creates an opportunity to build an application that bridges this gap. By combining optical music recognition with interactive visualization and real-time feedback, learners can practice with any piece of sheet music while receiving guided instruction.

### 1.2 Problem Statement

Beginner guitar players face several challenges:

1. Difficulty translating sheet notation to fretboard positions
2. Lack of immediate feedback during practice
3. Limited access to affordable, personalized instruction
4. Inability to practice with their own chosen music sheets
5. Difficulty maintaining proper timing and rhythm while learning

### 1.3 Objectives

The primary objectives of Guitar Tab Tutor are:

1. Enable users to upload their own PDF sheet music
2. Automatically extract note information and generate playable audio
3. Map musical notes to guitar fretboard positions
4. Provide synchronized visual and audio feedback during practice
5. Give instant feedback on correct and incorrect note timing
6. Create an accessible platform for self-directed learning

### 1.4 Scope

The project covers:

1. PDF sheet music upload and processing
2. Optical music recognition using Audiveris
3. MIDI generation and audio synthesis
4. Mobile application development for iOS and Android
5. Real-time animation and playback synchronization
6. Basic tuning and note feedback functionality

Out of scope:

1. Advanced music theory instruction
2. Support for non-standard tunings
3. Polyphonic playing detection
4. Performance metrics and progress tracking in current version

---

## CHAPTER 2: SRS (SOFTWARE REQUIREMENTS SPECIFICATION)

### 2.1 Functional Requirements

#### 2.1.1 User Authentication
- Users can create accounts with email and password
- Firebase authentication integration for secure login
- Session management and logout functionality

#### 2.1.2 Sheet Music Management
- Upload PDF files from device storage
- Preview uploaded PDF sheets
- Store uploaded files securely
- Delete or manage previously uploaded sheets

#### 2.1.3 Sheet Processing
- Extract notes from PDF using optical music recognition
- Generate MIDI representation of the score
- Create synchronized audio playback file
- Return timed note events to the mobile app

#### 2.1.4 Practice Interface
- Display fretboard with six strings and frets
- Show animated notes moving across the fretboard
- Play audio synchronized with visual animation
- Display current playhead position

#### 2.1.5 Feedback System
- Detect user audio input from device microphone
- Compare user input with expected notes
- Provide instant correctness feedback
- Prompt retries for incorrect notes

#### 2.1.6 Playback Controls
- Play and pause audio
- Seek to specific time positions
- Adjust playback speed
- Sync offset calibration for audio and visual alignment

#### 2.1.7 Tuning Utility
- Detect guitar string frequencies
- Display tuning status visually
- Guide users to proper tuning before practice

### 2.2 Non-Functional Requirements

#### 2.2.1 Performance
- Sheet processing completes within 30 seconds for standard scores
- Animation renders at 60 FPS on target devices
- Audio playback with minimal latency (under 100ms)
- Response time for API calls under 2 seconds

#### 2.2.2 Reliability
- 99% uptime for backend services
- Graceful error handling and user notifications
- Data backup and recovery mechanisms
- Secure storage of user uploads

#### 2.2.3 Usability
- Intuitive user interface for all user levels
- Clear visual feedback and guidance
- Responsive design for various screen sizes
- Accessibility features for users with different abilities

#### 2.2.4 Security
- Secure authentication and session management
- HTTPS encryption for data transmission
- Secure storage of uploaded files
- Protection against common web vulnerabilities

#### 2.2.5 Scalability
- Backend supports multiple concurrent users
- Efficient resource utilization
- Database optimization for quick queries
- Capable of handling peak loads

### 2.3 System Architecture

Guitar Tab Tutor follows a client-server architecture:

**Frontend Layer:**
- Flutter mobile application (iOS and Android)
- Handles user interface and interactions
- Manages local caching and state
- Performs MIDI-to-fretboard mapping

**Backend Layer:**
- FastAPI server for processing and API endpoints
- Handles sheet music processing pipeline
- Manages user authentication and data storage
- Serves static files and media

**External Services:**
- Firebase for authentication and data storage
- Audiveris for optical music recognition
- FluidSynth for audio synthesis
- ngrok for local development and testing

**Data Flow:**
1. User uploads PDF to mobile app
2. App sends PDF to backend via HTTP POST
3. Backend processes PDF through OMR pipeline
4. Backend returns notes and audio file path
5. App downloads audio and renders animation
6. App captures user input and provides feedback

### 2.4 Use Cases

#### Use Case 1: Beginner Learns a New Song
**Actor:** New guitar student
**Steps:**
1. User creates account and logs in
2. User selects and uploads PDF of desired song
3. System processes the sheet and returns notes and audio
4. User enters practice mode
5. System displays animated fretboard
6. User follows visual and audio guidance
7. System provides feedback on correctness
8. User practices until confident

#### Use Case 2: Teacher Demonstrates Song
**Actor:** Guitar teacher
**Steps:**
1. Teacher uploads sheet music in class
2. System processes and displays on projector
3. Teacher plays through once without user input
4. Students observe the correct positions and timing
5. Students then practice individually

#### Use Case 3: Self-Directed Learner Practices
**Actor:** Independent learner
**Steps:**
1. User has already logged in previously
2. User selects from library of previously uploaded sheets
3. User enters practice mode with audio sync calibration
4. User plays along with visual guide
5. System provides real-time feedback
6. User can loop sections or adjust playback speed

---

## CHAPTER 3: DESIGN AND DEVELOPMENT

### 3.1 System Design

#### 3.1.1 Architecture Overview

The system is designed as a distributed application with clear separation of concerns:

**Mobile Frontend (Flutter)**
- Presentation layer handling user interactions
- Local state management for UI responsiveness
- MIDI mapping and note visualization logic
- Audio playback and synchronization control

**Backend Server (FastAPI)**
- API endpoints for file upload and processing
- Music sheet recognition pipeline
- Audio generation and file serving
- Authentication and session management

**Data Storage (Firebase)**
- User authentication data
- User profiles and settings
- Upload history and metadata
- Cloud backup of processing results

### 3.2 Frontend Design

#### 3.2.1 User Interface Structure

**Authentication Pages:**
- Login page with email and password fields
- Sign up page for new users
- Password reset functionality

**Main Application Pages:**
- Home page with sheet selection and upload options
- PDF preview page for uploaded sheets
- Practice page with fretboard animation
- Settings page for audio sync and preferences

#### 3.2.2 Fretboard Highway Visualization

The core visualization component uses a custom painter to render:

**Static Elements:**
- Six horizontal guitar strings
- Fret markers at standard intervals
- String labels (E, B, G, D, A, E)
- Color coding for each string

**Dynamic Elements:**
- Animated note rectangles scrolling from right to left
- Playhead line fixed at 30% from the left
- Real-time position indicator
- Color-coded by string for quick identification

**Animation Parameters:**
- Scroll speed: 180 pixels per second
- Frame rate: 60 FPS
- Playhead position: Fixed at 30% of screen width
- Note width and height scaled appropriately

#### 3.2.3 Component Hierarchy

```
MyApp
├── AuthenticationPages
│   ├── LoginPage
│   └── SignupPage
├── MainAppPages
│   ├── HomePage
│   │   ├── SheetUploadWidget
│   │   └── RecentSheetsList
│   ├── PdfPreviewPage
│   │   ├── PdfViewerWidget
│   │   └── ProcessButton
│   ├── PracticePage
│   │   ├── FretboardHighwayPainter
│   │   ├── PlaybackControls
│   │   ├── SyncOffsetSlider
│   │   └── FeedbackDisplay
│   └── SettingsPage
└── SharedWidgets
    ├── BottomNavigationBar
    └── AppHeader
```

### 3.3 Backend Design

#### 3.3.1 API Endpoints

**POST /process-sheet/**
- Accepts multipart form data with PDF file
- Validates file format and size
- Returns JSON with notes array and audio file path
- Response format:
```json
{
  "id": "unique_identifier",
  "notes": [
    {
      "midi_pitch": 60,
      "start_time": 0.5,
      "duration": 0.25,
      "string_index": 3,
      "fret": 5
    }
  ],
  "audioPath": "outputs/id/id.wav",
  "status": "success"
}
```

**GET /outputs/{id}/{filename}**
- Serves generated audio files
- Supports range requests for streaming
- Returns appropriate MIME type

**POST /auth/login**
- Authenticates user credentials
- Returns authentication token

**POST /auth/signup**
- Creates new user account
- Returns authentication token

#### 3.3.2 Sheet Processing Pipeline

The backend processes sheets in seven sequential steps:

**Step 1: File Validation**
- Check file format is PDF
- Verify file size is within limits
- Generate unique processing ID

**Step 2: PDF Import**
- Load PDF using appropriate library
- Extract pages and metadata
- Prepare for optical recognition

**Step 3: Optical Music Recognition (Audiveris)**
- Run Audiveris executable on PDF
- Generate MusicXML output
- Parse XML structure

**Step 4: MusicXML Parsing**
- Load MXL file using music21
- Extract note information
- Preserve timing and duration data

**Step 5: MIDI Generation**
- Convert parsed score to MIDI format
- Ensure proper timing and note sequencing
- Output standard MIDI file

**Step 6: Timing Extraction (mido)**
- Parse MIDI using mido library
- Extract note-on and note-off events
- Convert timing to seconds
- Calculate note durations

**Step 7: Audio Synthesis (FluidSynth)**
- Load MIDI and SoundFont file
- Render MIDI to WAV audio
- Save output with processing ID
- Return path to frontend

### 3.4 Database Design

#### 3.4.1 Firebase Collections

**users**
```
{
  uid: string (primary key),
  email: string,
  created_at: timestamp,
  updated_at: timestamp
}
```

**uploads**
```
{
  upload_id: string (primary key),
  user_id: string (foreign key),
  filename: string,
  upload_date: timestamp,
  processing_status: string,
  notes_count: integer,
  audio_path: string
}
```

**processing_results**
```
{
  result_id: string (primary key),
  upload_id: string (foreign key),
  notes: array,
  audio_file_url: string,
  processing_time_ms: integer
}
```

### 3.5 Algorithm and Logic

#### 3.5.1 MIDI to Fretboard Mapping Algorithm

```
Function MapMidiToGuitar(midiPitch):
  Input: MIDI pitch number (40-88 for guitar range)
  Output: (stringIndex, fretNumber) or null

  Define standard tuning:
    strings = [40, 45, 50, 55, 59, 64]  // E, A, D, G, B, E pitches

  If midiPitch < 40 OR midiPitch > 88:
    Return null  // Out of range

  For each string in strings (index 0 to 5):
    Calculate fret = midiPitch - string_pitch
    If fret >= 0 AND fret <= 12:
      Add (string_index, fret) to candidates
      Apply preference weight based on region

  If multiple candidates exist:
    Return candidate with highest preference score
  Else if single candidate:
    Return that candidate
  Else:
    Return null  // No valid position found

End Function
```

#### 3.5.2 Audio Synchronization Algorithm

```
Function UpdateAnimationFrame(audioPositionMs):
  Input: Current audio playback position in milliseconds
  
  Adjust for sync offset:
    visualPosition = audioPositionMs + syncOffsetMs

  Calculate playhead screen position:
    playheadX = screenWidth * 0.3  // 30% from left

  For each note in notes:
    noteTiming = note.start_time_ms
    noteScreenPos = playheadX - (visualPosition - noteTiming) * scrollSpeed

    If noteScreenPos within viewport:
      Draw note at calculated position
    Else if noteScreenPos < playheadX:
      Mark note as passed
      If note was played correctly:
        Play success feedback
      Else:
        Play error feedback

  Request next frame via Ticker

End Function
```

#### 3.5.3 Feedback Detection Logic

```
Function EvaluateUserNote(capturedPitch, expectedPitch, timing):
  Input: User's played pitch, expected pitch, timing accuracy
  Output: Feedback message and correctness status

  pitchTolerance = 50 cents (0.5 semitones)
  timingTolerance = 200 milliseconds

  If abs(capturedPitch - expectedPitch) <= pitchTolerance:
    pitchCorrect = true
  Else:
    pitchCorrect = false

  If abs(timing - expectedTiming) <= timingTolerance:
    timingCorrect = true
  Else:
    timingCorrect = false

  If pitchCorrect AND timingCorrect:
    Return "Correct! Move to next note"
    status = success
  Else If pitchCorrect AND NOT timingCorrect:
    Return "Right note, but check timing"
    status = timing_error
  Else If NOT pitchCorrect AND timingCorrect:
    Return "Check the pitch, timing is good"
    status = pitch_error
  Else:
    Return "Try again - both pitch and timing need adjustment"
    status = both_error

  Request retry

End Function
```

---

## CHAPTER 4: ESTIMATION AND COSTING

### 4.1 Resource Estimation

#### 4.1.1 Development Team

| Role | Count | Duration (Months) |
|------|-------|-------------------|
| Flutter Developer | 2 | 4 |
| Backend Developer | 1 | 4 |
| UI/UX Designer | 1 | 2 |
| QA Engineer | 1 | 2 |
| Project Manager | 1 | 4 |

#### 4.1.2 Infrastructure and Tools

| Resource | Quantity | Cost per Unit | Total |
|----------|----------|--------------|-------|
| Development Machines | 4 | $1000 | $4000 |
| Server (6 months) | 1 | $30/month | $180 |
| Firebase Plan | 1 | $25/month | $150 |
| Software Licenses | Various | Varies | $500 |
| Testing Devices | 3 | $300 | $900 |

### 4.2 Cost Breakdown

#### 4.2.1 Personnel Costs

| Role | Monthly Rate | Duration | Total |
|------|--------------|----------|-------|
| Flutter Developers | $4000 | 4 months | $16000 |
| Backend Developer | $3000 | 4 months | $12000 |
| UI/UX Designer | $2500 | 2 months | $5000 |
| QA Engineer | $2000 | 2 months | $4000 |
| Project Manager | $3500 | 4 months | $14000 |

**Total Personnel Costs: $51,000**

#### 4.2.2 Infrastructure and Tools Costs

| Category | Cost |
|----------|------|
| Development Hardware | $4000 |
| Cloud Services | $330 |
| Software Licenses | $500 |
| Testing Equipment | $900 |
| Miscellaneous | $270 |

**Total Infrastructure: $6,000**

#### 4.2.3 Summary

| Category | Amount |
|----------|--------|
| Personnel | $51,000 |
| Infrastructure | $6,000 |
| Contingency (10%) | $5,700 |
| **Total Project Cost** | **$62,700** |

### 4.3 Actual Cost

[To be filled after project completion with actual expenses]

---

## CHAPTER 5: IMPLEMENTATION AND APPLICATION

### 5.1 Development Approach

Guitar Tab Tutor was developed using an iterative agile approach with the following phases:

#### 5.1.1 Planning and Design Phase (Week 1-2)
- Defined project scope and objectives
- Created system architecture design
- Designed user interface mockups
- Planned technology stack

#### 5.1.2 Backend Development Phase (Week 3-6)
- Set up FastAPI server
- Integrated Audiveris for music recognition
- Implemented music21 for MIDI processing
- Configured FluidSynth for audio synthesis
- Created API endpoints

#### 5.1.3 Frontend Development Phase (Week 5-8)
- Built Flutter mobile app structure
- Implemented authentication system
- Created PDF upload and preview functionality
- Developed fretboard highway visualization
- Integrated audio playback

#### 5.1.4 Integration and Testing Phase (Week 9-10)
- Connected frontend and backend
- Tested end-to-end workflows
- Performed performance optimization
- Conducted user acceptance testing

#### 5.1.5 Refinement and Deployment Phase (Week 11-12)
- Fixed identified issues
- Optimized user experience
- Prepared deployment packages
- Created documentation

### 5.2 Technologies Used

#### 5.2.1 Frontend Stack
- **Framework:** Flutter (Dart language)
- **IDE:** Android Studio / VS Code
- **State Management:** Provider / GetX
- **Audio Playback:** audioplayers package
- **HTTP Client:** dio package
- **Authentication:** firebase_auth
- **PDF Viewing:** pdf package
- **Video/Animation:** ticker and custom painters

#### 5.2.2 Backend Stack
- **Framework:** FastAPI (Python)
- **Server:** Uvicorn
- **OMR Engine:** Audiveris
- **Music Processing:** music21
- **MIDI Parsing:** mido
- **Audio Synthesis:** FluidSynth
- **SoundFont:** FluidR3_GM.sf2
- **Authentication:** Firebase Admin SDK
- **File Storage:** Firebase Cloud Storage

#### 5.2.3 Infrastructure
- **Cloud Services:** Firebase (Auth, Firestore, Storage)
- **Development Tunneling:** ngrok
- **Version Control:** Git / GitHub
- **Testing Tools:** Flutter testing framework, Postman

### 5.3 Key Implementation Details

#### 5.3.1 Sheet Music Processing Pipeline

The backend successfully implements a seven-step pipeline that transforms a PDF sheet into playable, synchronized content:

1. PDF file is uploaded via multipart HTTP request
2. Audiveris processes the PDF and generates MusicXML
3. music21 parses the MusicXML into a Score object
4. MIDI representation is extracted from the score
5. mido parses MIDI to extract precise note timing
6. FluidSynth renders MIDI to WAV audio using the SoundFont
7. API returns the notes array and audio file path

#### 5.3.2 Fretboard Animation System

The fretboard visualization uses Flutter's CustomPainter for efficient rendering:

- Notes move from right to left at consistent 180 pixels per second
- Playhead remains fixed at screen center (30% from left)
- Notes are color-coded by string for quick visual identification
- Animation is driven by a Ticker receiving audio position updates
- Smooth 60 FPS rendering on target devices

#### 5.3.3 Audio Synchronization

Real-time audio synchronization is maintained through:

- Using AudioPlayer.onPositionChanged as the timing source
- Adjustable sync offset slider for fine-tuning (±500ms range)
- Frame-by-frame position updates tied to audio playhead
- Interpolation between position updates for smooth motion

#### 5.3.4 Feedback System

The feedback mechanism evaluates user input against expected performance:

- Captures pitch data from device microphone
- Compares to expected note within tolerance windows
- Provides instant visual and auditory feedback
- Guides users to retry incorrect notes
- Tracks performance for future enhancement

### 5.4 Applications and Benefits

#### 5.4.1 Educational Applications

**In Classroom Settings:**
- Teachers can demonstrate finger positions and timing to entire classes
- Students can see correct playing before attempting independently
- Helps bridge gap between notation and physical performance

**For Self-Directed Learning:**
- Beginners can practice at home with their own sheet music
- No need for access to expensive private instruction
- Clear visual guidance reduces confusion and discouragement
- Immediate feedback improves learning efficiency

**For Music Programs:**
- Supports curriculum with interactive practice tools
- Helps students learning both sheet notation and tablature
- Useful for group workshops and demonstrations

#### 5.4.2 Community Benefits

- Lowers cost barrier for guitar learning accessibility
- Encourages participation in music and performance
- Supports local music culture and school performances
- Enables more people to develop musical skills

#### 5.4.3 Environmental Impact

- Reduces need for printed practice sheets and learning books
- Promotes reuse of existing sheet music through digital upload
- Minimizes paper waste in music education

#### 5.4.4 Institutional Relevance

Guitar Tab Tutor demonstrates practical application of computer science in music education. It showcases:

- Integration of multiple specialized software systems (OMR, audio synthesis)
- Full-stack application development across mobile and backend
- Real-time data processing and synchronization
- Firebase cloud services implementation
- User-centered design for accessibility

The project is relevant to CCCT by demonstrating how technology can solve real educational challenges and serve the local community.

### 5.5 Future Applications

The framework created by Guitar Tab Tutor enables potential future features:

- Polyphonic chord playing detection
- Performance metrics and progress tracking
- Adaptive difficulty adjustment
- Support for additional instruments (piano, violin, etc.)
- Integration with music theory lessons
- Multiplayer collaborative practice sessions
- Export of practice recordings and analysis

---

## CHAPTER 6: CONCLUSION AND FUTURE DIRECTIONS

### 6.1 Summary

Guitar Tab Tutor successfully demonstrates the potential of integrating digital music processing techniques into a beginner-friendly guitar practice application. By combining optical music recognition, MIDI processing, real-time audio synthesis, and interactive animation, the system transforms static sheet music into an engaging interactive learning experience.

The application addresses a significant gap in current music learning technology by allowing users to practice with their own printed music sheets rather than being limited to predefined lessons. This approach supports natural learning habits aligned with how musicians traditionally practice.

### 6.2 Achievements

Throughout development, the project successfully accomplished:

1. Built a complete end-to-end system from PDF input to interactive practice experience
2. Integrated specialized music processing tools into a cohesive pipeline
3. Created responsive mobile application with frame-synchronized animation
4. Implemented real-time audio playback with precision timing
5. Developed practical feedback system for learning guidance
6. Demonstrated system in working prototype form

The key achievement is the meaningful combination of symbolic music understanding and performance evaluation, linking expected musical content from sheets with actual performance from learners.

### 6.3 Future Enhancements

#### 6.3.1 Short-Term Improvements

- Polyphonic input detection for chord playing
- Performance metrics dashboard showing accuracy and improvement over time
- Section looping and playback speed adjustment
- Additional sound fonts for variety
- Offline mode capability

#### 6.3.2 Medium-Term Expansions

- Adaptive difficulty that adjusts based on user performance
- Support for left-handed guitar orientations
- Integration with music theory lessons and exercises
- Real-time score following to handle variations in playing
- Recording and playback of user sessions

#### 6.3.3 Long-Term Vision

- Support for additional instruments (piano, violin, bass, drums)
- Multiplayer collaborative learning sessions
- Integration with sheet music libraries and databases
- AI-powered practice recommendations
- Community features for sharing progress and songs
- Integration with online guitar lessons and tutorials

### 6.4 Conclusion

Guitar Tab Tutor presents a practical and learner-centered approach to guitar education by bridging the gap between traditional music sheets and interactive digital learning systems. The work highlights how existing music processing techniques, when thoughtfully integrated, can contribute to more engaging and effective music learning experiences.

While the current implementation focuses on core functionalities, the framework provides a strong foundation for the enhancements listed above. The project demonstrates that technology can make music education more accessible, engaging, and effective for learners at all levels.

---

## ACRONYMS

| Acronym | Full Form |
|---------|-----------|
| OMR | Optical Music Recognition |
| MIDI | Musical Instrument Digital Interface |
| MXL | Compressed MusicXML |
| WAV | Waveform Audio File Format |
| PDF | Portable Document Format |
| API | Application Programming Interface |
| HTTP | Hypertext Transfer Protocol |
| JSON | JavaScript Object Notation |
| SRS | Software Requirement Specification |
| UI | User Interface |
| UX | User Experience |
| FPS | Frames Per Second |
| IDE | Integrated Development Environment |
| SSH | Secure Shell |
| HTTPS | Hypertext Transfer Protocol Secure |

---

## REFERENCES

1. Flutter Documentation. (2024). "Flutter Framework." Retrieved from https://flutter.dev/docs

2. FastAPI Documentation. (2024). "FastAPI - Modern, fast web framework for building APIs." Retrieved from https://fastapi.tiangolo.com

3. music21. (2024). "music21: A toolkit developed at MIT." Retrieved from http://web.mit.edu/music21/

4. Audiveris. (2024). "Audiveris: Optical Music Recognition (OMR)." Retrieved from https://audiveris.github.io/

5. FluidSynth. (2024). "FluidSynth - Real-time software synthesizer." Retrieved from http://www.fluidsynth.org/

6. Firebase Documentation. (2024). "Firebase Platform." Retrieved from https://firebase.google.com/docs

7. mido. (2024). "mido - MIDI Objects for Python." Retrieved from https://mido.readthedocs.io/

8. audioplayers. (2024). "audioplayers - A Flutter audio plugin." Retrieved from https://pub.dev/packages/audioplayers

9. Dart Language Documentation. (2024). "Dart Programming Language." Retrieved from https://dart.dev/guides

10. Python Documentation. (2024). "Python 3 Official Documentation." Retrieved from https://docs.python.org/3/

---

**END OF REPORT**

*This report is hard-bound and submitted in compliance with CCCT guidelines.*
