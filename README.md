# Ma’ta

## Introduction

Ma’ta is an AI-based Android healthcare decision-support application designed to help users make more informed decisions about when and where to seek medical care. Users can describe their symptoms in natural language, and the system uses Natural Language Processing (NLP) to process the input and extract symptoms. The system then identifies possible medical conditions, assesses the urgency of the case, and recommends an appropriate healthcare service. Ma’ta is intended to support healthcare decision-making and does not provide a definitive diagnosis or replace professional medical consultation.

## Technologies Used

- Flutter
- Dart
- Python
- FastAPI
- Firebase
- Machine Learning
- Natural Language Processing (NLP)
- Gemini API

## How to Launch

The steps are the same on every system, but some terminal commands differ. Follow **macOS / Linux** or **Windows** below.

### macOS / Linux

Clone the repository and open its directory:

```bash
git clone https://github.com/Raghad-Alkhurayyif/2026-GP1-Group8.git
cd 2026-GP1-Group8
```

Set up the server:

```bash
python3 -m venv mata_server/.venv
source mata_server/.venv/bin/activate
python -m pip install -r mata_server/requirements.txt
cp mata_server/.env.example mata_server/.env
```

Add a valid Gemini API key to `mata_server/.env`, then run the server:

```bash
python -m uvicorn mata_server.main:app \
  --reload \
  --host 0.0.0.0 \
  --port 8000
```

In another terminal, run the Flutter application:

```bash
cd mata_app
flutter pub get
flutter devices
flutter run -d <device-id>
```

### Windows

Run these commands in **PowerShell**. Where the **Command Prompt (cmd)** command is different, it is shown separately.

Clone the repository and open its directory:

```powershell
git clone https://github.com/Raghad-Alkhurayyif/2026-GP1-Group8.git
cd 2026-GP1-Group8
```

Create the virtual environment and activate it.

PowerShell:

```powershell
py -m venv mata_server\.venv
mata_server\.venv\Scripts\Activate.ps1
```

If PowerShell says that running scripts is disabled, run this once and then activate again:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

Command Prompt (cmd):

```bat
py -m venv mata_server\.venv
mata_server\.venv\Scripts\activate.bat
```

Install the requirements and create the `.env` file.

PowerShell:

```powershell
python -m pip install -r mata_server\requirements.txt
Copy-Item mata_server\.env.example mata_server\.env
```

Command Prompt (cmd):

```bat
python -m pip install -r mata_server\requirements.txt
copy mata_server\.env.example mata_server\.env
```

Add a valid Gemini API key to `mata_server\.env` (for example with `notepad mata_server\.env`), then run the server. This command is the same in PowerShell and cmd:

```powershell
python -m uvicorn mata_server.main:app --reload --host 0.0.0.0 --port 8000
```

In another terminal, run the Flutter application. These commands are the same in PowerShell and cmd:

```powershell
cd mata_app
flutter pub get
flutter devices
flutter run -d <device-id>
```

If `py` is not found, use `python` instead. If Windows Firewall asks whether to allow Python, allow it on private networks so the emulator or phone can reach the server.

### Connecting the app to the server

For the Android emulator, the application connects to the local server through `http://10.0.2.2:8000`.
