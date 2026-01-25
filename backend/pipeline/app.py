import os
import json
from typing import List
from datetime import datetime, timedelta

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

from dotenv import load_dotenv
from groq import Groq
from pydantic import BaseModel

# ===============================
# LOAD ENV
# ===============================
load_dotenv()

GROQ_API_KEY = os.getenv("GROQ_API_KEY")
if not GROQ_API_KEY:
    raise RuntimeError("GROQ_API_KEY missing from .env file")

# Initialize Groq client
try:
    groq_client = Groq(api_key=GROQ_API_KEY)
    print("✅ Groq client initialized")
except Exception as e:
    print(f"❌ ERROR: Groq initialization failed. Install: pip install groq")
    raise e

# ===============================
# FASTAPI APP
# ===============================
app = FastAPI(title="MediBuddy Medication Adherence Server")

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",
        "http://localhost:5173",
        "http://localhost:5174",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:5173",
        "http://127.0.0.1:5174"
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ===============================
# DATA MODELS
# ===============================
class Medicine(BaseModel):
    id: str
    name: str
    schedule: List[str]

class Log(BaseModel):
    date: str
    medicine: str
    time: str
    status: str

class AdherenceRequest(BaseModel):
    patientId: str
    medicines: List[Medicine]
    logs: List[Log]

# ===============================
# HEALTH CHECK
# ===============================
@app.get("/health")
def health_check():
    return {"status": "ok", "message": "Server is running", "ai_provider": "groq"}

# ===============================
# AI GENERATION
# ===============================
def generate_summary(prompt: str) -> str:
    """Generate summary using Groq API"""
    try:
        response = groq_client.chat.completions.create(
            model="llama-3.1-8b-instant",  # Fast and efficient
            messages=[
                {
                    "role": "system",
                    "content": "You are a medical adherence analyst. Provide brief, clinical summaries in 2-3 sentences."
                },
                {
                    "role": "user",
                    "content": prompt
                }
            ],
            temperature=0.2,
            max_tokens=200
        )
        
        return response.choices[0].message.content.strip()
        
    except Exception as e:
        print(f"⚠️ Groq API error: {e}")
        return "Unable to generate AI summary at this time."

# ===============================
# HELPER FUNCTIONS
# ===============================
def calculate_timeline_data(logs: List[Log], last_7_days: List[str]):
    """Calculate timeline data from logs"""
    timeline = []
    
    print(f"📅 Processing timeline for days: {last_7_days}")
    print(f"📝 Available log dates: {[log.date for log in logs]}")
    
    for day in last_7_days:
        # Convert "Jan 19" to "2026-01-19" format for matching
        try:
            day_obj = datetime.strptime(f"{day} 2026", "%b %d %Y")
        except:
            # Fallback if date parsing fails
            day_obj = datetime.now()
        
        day_str = day_obj.strftime("%Y-%m-%d")
        
        day_logs = [log for log in logs if log.date == day_str]
        
        print(f"  {day} ({day_str}): {len(day_logs)} logs")
        
        # Aggregate statuses for each time slot - if ANY medicine was taken/missed/delayed
        morning_logs = [log for log in day_logs if log.time == "morning"]
        afternoon_logs = [log for log in day_logs if log.time == "afternoon"]
        night_logs = [log for log in day_logs if log.time == "night"]
        
        # Priority: missed > delayed > taken > pending
        def get_slot_status(slot_logs):
            if not slot_logs:
                return "pending"
            statuses = [log.status for log in slot_logs]
            if "missed" in statuses:
                return "missed"
            if "delayed" in statuses:
                return "delayed"
            if "taken" in statuses:
                return "taken"
            return "pending"
        
        morning = get_slot_status(morning_logs)
        afternoon = get_slot_status(afternoon_logs)
        night = get_slot_status(night_logs)
        
        timeline.append({
            "date": day,
            "morning": morning,
            "afternoon": afternoon,
            "night": night
        })
    
    return timeline

def calculate_medicine_adherence(medicines: List[Medicine], logs: List[Log]):
    """Calculate adherence percentage for each medicine"""
    medicine_data = []
    
    print(f"💊 Calculating adherence for {len(medicines)} medicines")
    
    for med in medicines:
        med_logs = [log for log in logs if log.medicine == med.name]
        
        taken = len([log for log in med_logs if log.status == "taken"])
        delayed = len([log for log in med_logs if log.status == "delayed"])
        missed = len([log for log in med_logs if log.status == "missed"])
        
        total = taken + delayed + missed
        
        # If no logs exist, adherence is 0
        if total == 0:
            adherence = 0
            print(f"  ⚠️ {med.name}: No logs found (0%)")
        else:
            adherence = round((taken / total * 100))
            print(f"  ✅ {med.name}: {taken}/{total} taken ({adherence}%)")
        
        medicine_data.append({
            "name": med.name,
            "adherence": adherence
        })
    
    return medicine_data

# ===============================
# ADHERENCE ANALYSIS API
# ===============================
@app.post("/analyze-adherence")
async def analyze_adherence(payload: AdherenceRequest):
    print("=" * 50)
    print(f"✅ Request received for patient: {payload.patientId}")
    print(f"📊 Medicines: {len(payload.medicines)}")
    print(f"📝 Logs: {len(payload.logs)}")
    print("=" * 50)
    
    try:
        # Generate last 7 days
        today = datetime.now()
        last_7_days = [(today - timedelta(days=i)).strftime("%b %d") for i in range(6, -1, -1)]
        
        # 🔹 CALCULATE DATA LOCALLY
        print("📊 Calculating timeline and adherence data...")
        timeline_data = calculate_timeline_data(payload.logs, last_7_days)
        medicine_data = calculate_medicine_adherence(payload.medicines, payload.logs)
        
        print(f"✅ Calculated {len(timeline_data)} timeline entries")
        print(f"✅ Calculated {len(medicine_data)} medicine adherence scores")
        
        # 🔹 GENERATE SUMMARY WITH GROQ
        print("🤖 Generating summary with Groq...")
        
        # Calculate overall stats for summary
        total_taken = sum(1 for log in payload.logs if log.status == "taken")
        total_missed = sum(1 for log in payload.logs if log.status == "missed")
        total_delayed = sum(1 for log in payload.logs if log.status == "delayed")
        total_logs = len(payload.logs)
        
        overall_adherence = round((total_taken / total_logs * 100) if total_logs > 0 else 0)
        
        summary_prompt = f"""Analyze this medication adherence data and provide a brief clinical summary (2-3 sentences):

Patient ID: {payload.patientId}
Total Medications: {len(payload.medicines)}
Total Logged Doses: {total_logs}
- Taken: {total_taken} ({overall_adherence}%)
- Delayed: {total_delayed}
- Missed: {total_missed}

Individual Medicine Adherence:
{json.dumps(medicine_data, indent=2)}

Recent Activity (last 5 entries):
{json.dumps([{"date": log.date, "medicine": log.medicine, "time": log.time, "status": log.status} for log in payload.logs[-5:]], indent=2)}

Provide a brief, professional summary about the patient's adherence pattern. Mention any concerning trends."""
        
        summary = generate_summary(summary_prompt)
        
        print(f"✅ Summary generated: {summary[:100]}...")
        
        # 🔹 RETURN COMPLETE RESULT
        result = {
            "summary": summary,
            "timelineData": timeline_data,
            "medicineData": medicine_data
        }
        
        print("✅ Response ready")
        return result

    except Exception as e:
        print(f"❌ ERROR: {type(e).__name__}: {str(e)}")
        
        # Fallback: return data without AI summary
        print("⚠️ Falling back to manual calculation only")
        
        try:
            timeline_data = calculate_timeline_data(payload.logs, last_7_days)
            medicine_data = calculate_medicine_adherence(payload.medicines, payload.logs)
        except:
            timeline_data = []
            medicine_data = []
        
        return {
            "summary": f"Patient {payload.patientId} has {len(payload.medicines)} medications with {len(payload.logs)} logged doses.",
            "timelineData": timeline_data,
            "medicineData": medicine_data
        }

# ===============================
# RUN SERVER
# ===============================
if __name__ == "__main__":
    print("=" * 60)
    print("💊 MediBuddy Medication Adherence Server")
    print("=" * 60)
    print("📍 URL: http://localhost:5003")
    print("🎯 Endpoints:")
    print("   - POST /analyze-adherence")
    print("   - GET  /health")
    print("=" * 60)
    print("🤖 AI Provider: Groq (llama-3.1-8b-instant)")
    print("⚠️  Make sure GROQ_API_KEY is set in .env file")
    print("=" * 60)

    uvicorn.run(
        app,
        host="0.0.0.0",
        port=5003,
        log_level="info"
    )
