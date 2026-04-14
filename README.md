# TutorTable

TutorTable is a local-first macOS app for private tutors. It keeps student records, lesson history, session payments, upcoming lesson reminders, and optional voice notes for each session.

## What it does

- Tracks students, subjects, rates, and tutor notes
- Tracks lesson sessions with payment status and reminder timing
- Stores lesson notes and homework follow-ups for each session
- Saves voice notes from your Mac microphone into the same local data folder
- Registers a global hotkey to open TutorTable or bring it to the front
- Writes everything to a readable JSON file in `~/Documents/TutorTable`

## Local data

TutorTable creates this folder on first launch:

`~/Documents/TutorTable`

Inside that folder:

- `tutor-data.json` contains all students and sessions in pretty-printed JSON
- `AudioNotes/` stores any lesson voice notes you record

## Build

From this project folder:

```bash
chmod +x build.sh
./build.sh
open build/TutorTable.app
```

## Notes

- The app first tries the global hotkey `Command + Option + T`.
- If macOS or another app already owns that shortcut, TutorTable falls back to another `T` shortcut.
- Notifications are local macOS notifications, so the first launch asks for reminder access.
- Microphone recording asks for microphone permission the first time you record a voice note.
