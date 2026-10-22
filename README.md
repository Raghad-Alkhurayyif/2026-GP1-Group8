# Ma’ta

## Introduction

Ma’ta is an AI-based Android healthcare decision-support application designed to help users make more informed decisions about when and where to seek medical care.

Users can describe their symptoms in natural language. The system processes the description, extracts the mentioned symptoms, asks follow-up questions when clarification is needed, and allows the user to review the identified symptoms.

Ma’ta is intended to support healthcare decision-making. It does not provide a definitive diagnosis or replace professional medical consultation.

## Technologies Used

- Flutter
- Dart
- Python
- FastAPI
- Firebase Authentication
- Cloud Firestore
- Natural Language Processing
- Gemini API

## Project Structure

- `mata_app/` — Flutter Android application
- `mata_nlp/` — Symptom-extraction component
- `mata_server/` — FastAPI server connecting the application to the NLP component

## Requirements

Before running the project, install:

- Flutter
- Android Studio and an Android emulator
- Python 3
- Git

## How to Launch

### 1. Clone the repository

```bash
git clone https://github.com/Raghad-Alkhurayyif/2026-GP1-Group8.git
cd 2026-GP1-Group8
```

### 2. Set up the server

Create and activate a Python virtual environment:

```bash
python3 -m venv mata_server/.venv
source mata_server/.venv/bin/activate
```

Install the required Python packages:

```bash
python -m pip install -r mata_server/requirements.txt
```

Create the environment file:

```bash
cp mata_server/.env.example mata_server/.env
```

Open `mata_server/.env` and replace the placeholder with a valid Gemini API key:

```env
GEMINI_API_KEY=your_actual_api_key
```

Start the server from the repository root:

```bash
python -m uvicorn mata_server.main:app \
  --reload \
  --host 0.0.0.0 \
  --port 8000
```

The server will run at:

```text
http://localhost:8000
```

### 3. Run the Flutter application

Open another terminal and move to the Flutter project:

```bash
cd mata_app
```

Install the Flutter dependencies:

```bash
flutter pub get
```

Check the available devices:

```bash
flutter devices
```

Run the application using the displayed Android emulator ID:

```bash
flutter run -d <device-id>
```

For example:

```bash
flutter run -d emulator-5554
```

The Android emulator communicates with the local server through:

```text
http://10.0.2.2:8000
```

## Environment Variables

The Gemini API key must be stored locally inside:

```text
mata_server/.env
```

Do not commit this file or share the API key. The repository includes `.env.example` only as a configuration template.

## Project Status

Ma’ta is currently under development. Sprint 1 includes user-account features, free-text symptom entry, symptom extraction, follow-up clarification questions, and symptom review.
