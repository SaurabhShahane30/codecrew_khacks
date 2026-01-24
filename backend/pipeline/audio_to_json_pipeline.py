import os
import sys
import time
import json
import subprocess
import shutil
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import uvicorn

from dotenv import load_dotenv
from groq import Groq
import requests

# ===============================
# LOAD ENV
# ===============================
load_dotenv()

ASSEMBLYAI_API_KEY = os.getenv("ASSEMBLYAI_API_KEY")
GROQ_API_KEY = os.getenv("GROQ_API_KEY")

if not ASSEMBLYAI_API_KEY:
    raise RuntimeError("ASSEMBLYAI_API_KEY missing")
if not GROQ_API_KEY:
    raise RuntimeError("GROQ_API_KEY missing")

# Initialize Groq client
try:
    groq_client = Groq(api_key=GROQ_API_KEY)
except Exception as e:
    print(f"ERROR: Groq initialization failed. Install latest groq + httpx", file=sys.stderr)
    raise e

UPLOAD_HEADERS = {"authorization": ASSEMBLYAI_API_KEY}
HEADERS = {
    "authorization": ASSEMBLYAI_API_KEY,
    "content-type": "application/json"
}

# ===============================
# FASTAPI APP
# ===============================
app = FastAPI(title="MediBuddy Voice Processing Server")

# Enable CORS for Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify your Flutter app's origin
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Create necessary directories
os.makedirs("uploads", exist_ok=True)
os.makedirs("input", exist_ok=True)
os.makedirs("output", exist_ok=True)

# ===============================
# HELPER FUNCTIONS
# ===============================

def convert_to_wav(input_file: str) -> str:
    """Convert audio to WAV format"""
    base = os.path.splitext(os.path.basename(input_file))[0]
    wav_path = os.path.join("input", f"{base}.wav")

    cmd = [
        "ffmpeg", "-y",
        "-i", input_file,
        "-ac", "1",
        "-ar", "16000",
        "-c:a", "pcm_s16le",
        "-vn",
        "-hide_banner",
        "-loglevel", "error",
        wav_path
    ]

    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode != 0:
        raise RuntimeError(f"FFmpeg error: {result.stderr.decode()}")

    return wav_path


def upload_audio(path: str) -> str:
    """Upload audio to AssemblyAI"""
    with open(path, "rb") as f:
        r = requests.post(
            "https://api.assemblyai.com/v2/upload",
            headers=UPLOAD_HEADERS,
            data=f
        )
    r.raise_for_status()
    return r.json()["upload_url"]


def start_transcription(audio_url: str) -> str:
    """Start transcription job"""
    payload = {
        "audio_url": audio_url,
        "speaker_labels": False
    }
    r = requests.post(
        "https://api.assemblyai.com/v2/transcript",
        headers=HEADERS,
        json=payload
    )
    r.raise_for_status()
    return r.json()["id"]


def wait_for_result(tid: str) -> dict:
    """Poll for transcription result"""
    while True:
        r = requests.get(
            f"https://api.assemblyai.com/v2/transcript/{tid}",
            headers=HEADERS
        )
        r.raise_for_status()
        res = r.json()

        if res["status"] == "completed":
            return res

        if res["status"] == "error":
            raise RuntimeError(res["error"])

        time.sleep(3)


def parse_medication_info(transcript_json: dict) -> dict:
    """Parse medication information from transcript"""
    text = transcript_json.get("text", "")
    
    if not text:
        return {}

    prompt = f"""
You are a medication information extraction system.

Extract medication details from the user's voice input and return ONLY valid JSON.
No markdown. No explanations. No code blocks.

The JSON MUST strictly follow this structure:

{{
  "name": string (medicine name),
  "type": string (one of: "tablet", "syrup", "other"),
  "intakeTimes": [string] (array of: "Before Breakfast", "After Breakfast", "Before Lunch", "After Lunch", "Before Dinner", "After Dinner"),
  "customTimes": [string] (array of time strings in HH:MM format),
  "frequency": string (one of: "Daily", "Alternate Days", "Specific Days"),
  "startDay": string (one of: "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"),
  "days": [string] (array of days: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]),
  "doseCount": number (tablets count or ml for syrup, default 1 for tablet, 5 for syrup),
  "isCritical": boolean (is this a critical medication),
  "durationDays": number (duration in days)
}}

Rules:
- Extract medicine name carefully
- Identify type: tablet, syrup, or other
- Parse meal-related timings (before/after breakfast/lunch/dinner)
- Extract any specific times mentioned (convert to HH:MM format)
- Determine frequency pattern (daily, alternate days, or specific days)
- If alternate days, set startDay
- If specific days mentioned, populate days array
- Extract dosage/quantity
- Check if medication is mentioned as critical/important
- Extract duration if mentioned
- Use reasonable defaults if information is missing
- DO NOT hallucinate - only extract what is clearly stated

User's voice input:
{text}
"""

    response = groq_client.chat.completions.create(
        model="llama-3.1-8b-instant",
        messages=[{"role": "user", "content": prompt}],
        temperature=0.1
    )

    try:
        content = response.choices[0].message.content.strip()
        # Remove markdown code blocks if present
        if content.startswith("```"):
            content = content.split("```")[1]
            if content.startswith("json"):
                content = content[4:]
        data = json.loads(content)
    except Exception as e:
        print(f"JSON Parse Error: {e}", file=sys.stderr)
        data = {}

    # Provide defaults for missing fields
    result = {
        "name": data.get("name", ""),
        "type": data.get("type", "tablet"),
        "intakeTimes": data.get("intakeTimes", []),
        "customTimes": data.get("customTimes", []),
        "frequency": data.get("frequency", "Daily"),
        "startDay": data.get("startDay", "Mon"),
        "days": data.get("days", ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]),
        "doseCount": data.get("doseCount", 1 if data.get("type", "tablet") == "tablet" else 5),
        "isCritical": data.get("isCritical", False),
        "durationDays": data.get("durationDays", 7)
    }

    return result


# ===============================
# API ENDPOINTS
# ===============================

@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "service": "MediBuddy Voice Processing Server",
        "status": "running",
        "endpoints": {
            "health": "/health",
            "process_voice": "/api/medicine/process-voice"
        }
    }


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "Voice processing server is running",
        "timestamp": time.time(),
        "service": "medication-voice-processor"
    }


@app.post("/api/medicine/process-voice")
async def process_voice(audio: UploadFile = File(...)):
    """
    Process voice recording and extract medication information
    
    Args:
        audio: Audio file (any format supported by ffmpeg)
    
    Returns:
        JSON with extracted medication details
    """
    temp_audio_path = None
    wav_path = None
    
    try:
        # Save uploaded file
        temp_audio_path = f"uploads/{audio.filename}"
        with open(temp_audio_path, "wb") as buffer:
            shutil.copyfileobj(audio.file, buffer)
        
        print(f"📥 Received audio file: {audio.filename}")
        
        # Convert to WAV
        print("🔄 Converting to WAV...")
        wav_path = convert_to_wav(temp_audio_path)
        
        # Upload to AssemblyAI
        print("☁️  Uploading to AssemblyAI...")
        audio_url = upload_audio(wav_path)
        
        # Start transcription
        print("🎤 Starting transcription...")
        transcript_id = start_transcription(audio_url)
        
        # Wait for result
        print("⏳ Waiting for transcription...")
        transcript = wait_for_result(transcript_id)
        
        # Parse medication info
        print("🧠 Extracting medication details...")
        medication_data = parse_medication_info(transcript)
        
        print("✅ Processing complete!")
        print(f"📋 Extracted: {medication_data.get('name', 'Unknown')}")
        
        return JSONResponse(content=medication_data)
        
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
        
    finally:
        # Cleanup
        if temp_audio_path and os.path.exists(temp_audio_path):
            os.remove(temp_audio_path)
        if wav_path and os.path.exists(wav_path):
            os.remove(wav_path)


# ===============================
# RUN SERVER
# ===============================

if __name__ == "__main__":
    print("=" * 50)
    print("🎤 MediBuddy Voice Processing Server")
    print("=" * 50)
    print("📍 Starting server on http://0.0.0.0:5001")
    print("🎯 Endpoint: POST /api/medicine/process-voice")
    print("=" * 50)
    print()
    
    uvicorn.run(
        app, 
        host="0.0.0.0", 
        port=5001,
        log_level="info"
    )