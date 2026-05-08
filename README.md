# Care Companion

A Flutter application designed to support seniors and their caregivers — helping manage medications, health information, emergency services, and real-time communication between care networks.

🌐 **Live app:** [care-companion-43428.web.app](https://care-companion-43428.web.app)

## Features

### For Seniors
- **Medication Management** — Add medications with custom schedules (daily, specific days, every X days, weekly, monthly), set refill reminders, and track adherence history
- **AI Medication Scan** — Upload a photo of a medication label or prescription and have details auto-filled using AI vision
- **Health Profile** — Store blood group, allergies, health conditions, mobility needs, and accessibility preferences
- **Check on Me Alerts** — Send a one-tap alert to all linked caregivers with a 30-second cooldown
- **Caregiver Messages** — Receive messages from caregivers directly on the home screen with auto text-to-speech readout
- **Emergency Services** — Find nearby hospitals, ERs, clinics, and pharmacies using OpenStreetMap with radius filtering (Nearest, 1km, 2km, 5km, 10km)
- **Caregiver Code** — Generate a shareable code so caregivers can link to your account

### For Caregivers
- **Senior Dashboard** — View linked seniors' profiles, medication adherence, and health details
- **Real-time Alerts** — Receive and resolve Check on Me alerts from seniors in real time
- **Message Seniors** — Send preset or custom messages to any linked senior; messages are displayed and spoken aloud on the senior's device
- **Link Seniors** — Connect to a senior's account by entering their caregiver code
- **Adherence Tracking** — See medication taken/skipped history with adherence percentage charts
- **Multiple Seniors** — Support for caregivers linked to more than one senior

### Onboarding
- **Manual Questionnaire** — Fill in health and preference details via a structured form
- **Voice Assistant** — Answer setup questions hands-free using speech recognition and text-to-speech

## Tech Stack

- **Flutter** — Cross-platform UI (iOS, Android, Web)
- **Firebase Auth** — Email/password authentication with password reset
- **Cloud Firestore** — Real-time data sync for users, medications, alerts, and messages
- **Firebase Hosting** — Web deployment
- **OpenRouter AI** — AI-powered medication image scanning (vision model)
- **OpenStreetMap / Overpass API** — Nearby emergency services lookup
- **flutter_local_notifications** — Medication reminders
- **flutter_tts** — Text-to-speech for caregiver messages and voice assistant
- **speech_to_text** — Voice assistant onboarding

## Getting Started

### Prerequisites
- Flutter SDK 3.x
- Firebase project with Auth and Firestore enabled
- OpenRouter API key (for AI medication scan)

### Setup

1. Clone the repo
   ```bash
   git clone https://github.com/Jaisachdeva007/care-companion.git
   cd care-companion
   ```

2. Install dependencies
   ```bash
   flutter pub get
   ```

3. Configure Firebase
   - Add your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) to the appropriate directories
   - Update `lib/firebase_options.dart` with your Firebase project config

4. Add your API key
   ```dart
   // lib/config/app_config.dart  (gitignored — create this file locally)
   class AppConfig {
     static const String openRouterApiKey = 'YOUR_API_KEY_HERE';
   }
   ```

5. Run the app
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── models/          # Data models (AppUser, Medication, AlertItem, CaregiverMessage)
├── screens/         # All UI screens
├── services/        # Firebase, AI, notification, and auth services
├── widgets/         # Shared widgets (bottom nav bar)
└── config/          # Local config (gitignored)
```
