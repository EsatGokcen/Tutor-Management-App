# TutorTable

TutorTable is a local-first macOS app for private tutors. It helps you manage students, sessions, reminders, calendar scheduling, unavailable time, payments, advance-credit coverage, Apple Calendar sync, and voice-driven session updates from one desktop app.

## Current Features

- Student management with saved defaults for subject and hourly rate
- Session management with saved defaults for session type, location, and payment method
- Clickable calendar view with monthly lesson overview
- Calendar day click-to-add session flow and existing session detail/edit flow
- Time-off booking directly from the calendar, with unavailable dates visible in the month view
- Session blocking when a lesson overlaps saved unavailable time
- Local reminder scheduling for sessions
- Apple Calendar integration that can create, update, and delete synced lesson events
- Payment tracking for paid, unpaid, and credit-covered lessons
- Advance credit tracking for bulk lesson payments and discounted prepaid hours
- Payment reporting for weekly, monthly, and yearly timeframes
- Overview dashboard with income and recent lesson memory
- Voice command input for creating sessions and updating payments
- Global hotkey support to reopen the app
- Fully local storage in a readable JSON file

## Local Data

TutorTable creates this folder on first launch:

`~/Documents/TutorTable`

Inside that folder:

- `tutor-data.json` contains app settings, students, sessions, and advance-credit purchases
- synced Apple Calendar settings and event links are stored in the same local data file
- supporting system files are stored there as needed for reminders and launcher status

## Voice Commands

TutorTable uses Apple’s built-in speech recognition on macOS. The app can listen for commands such as:

- creating a new session from spoken date, time, student, duration, and payment details
- updating an existing session payment status from speech

TutorTable no longer stores standalone audio-note recordings. The microphone is used for live speech-to-text command input instead.

## Apple Calendar Sync

TutorTable can sync lesson sessions into a calendar that is already available in Apple Calendar on your Mac.

- connect the integration from the Apple Calendar card at the top of the Settings page
- choose the target calendar you want TutorTable to use
- for iPhone visibility, choose an iCloud, Google, or Exchange-backed calendar rather than an `On My Mac` calendar
- new sessions, session edits, and session deletes will sync automatically once sync is enabled
- session notes sent to Apple Calendar include separate `Lesson Notes` and `Homework` sections inside the event notes field
- you can manually run `Sync Existing Sessions Now` from Settings after connecting

## Payments And Credit Coverage

TutorTable supports both direct lesson payments and advance-credit workflows.

- `Paid` means the lesson was paid directly
- `Unpaid` means the lesson still needs payment
- `Credit Covered` means the lesson was automatically covered by a student’s prepaid lesson credit

The Payments page also tracks:

- total earned
- directly paid income
- credit received
- credit-covered lesson value
- unpaid sessions
- remaining active student credit balances

## Build

From this project folder:

```bash
chmod +x build.sh
./build.sh
open build/TutorTable.app
```

## Notes

- The app first tries the global hotkey `Command + Shift + T`
- If that shortcut is unavailable, TutorTable falls back to another `T` shortcut
- Notifications are local macOS notifications, so the app requests reminder permission
- Apple Calendar sync requests Calendar permission on first connect
- Voice commands request microphone and speech-recognition permission on first use
- The build script regenerates the app icon before building the app bundle
