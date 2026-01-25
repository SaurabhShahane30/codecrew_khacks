import os
import json
import re
import io
from datetime import datetime


from typing import List

from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import uvicorn

from dotenv import load_dotenv
from PIL import Image

import google.generativeai as genai
from datetime import datetime
from zoneinfo import ZoneInfo   # Python 3.9+


# ===============================
# LOAD ENV
# ===============================
load_dotenv()

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
if not GEMINI_API_KEY:
    raise RuntimeError("GEMINI_API_KEY missing")

genai.configure(api_key=GEMINI_API_KEY)
model = genai.GenerativeModel("gemini-2.5-flash")

# ===============================
# FASTAPI APP
# ===============================
app = FastAPI(title="MediBuddy Prescription Image + PDF Server")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ===============================
# HELPERS
# ===============================
def _clean_json(text: str) -> str:
    text = re.sub(r"```json", "", text)
    text = re.sub(r"```", "", text)
    return text.strip()


def _extract_from_image(image: Image.Image) -> List[dict]:
    prompt = """
You are a medical prescription extraction system. Analyze this prescription image carefully.

Extract ALL medicines visible in the prescription and return ONLY valid JSON.
No markdown. No explanations. No code blocks.

The JSON MUST strictly follow this structure:

[
  {
  "name": string (medicine name),
  "type": string (one of: "tablet", "syrup", "other"),
  "intakeTimes": [string] (array of: "Before Breakfast", "After Breakfast", "Before Lunch", "After Lunch", "Before Dinner", "After Dinner"),
  "customTimes": [string] (array of time strings in HH:MM format),
  "frequency": string (one of: "Daily", "Alternate Days"),
  "doseCount": number (tablets count or ml for syrup, default 1 for tablet, 5 for syrup),
  "isCritical": boolean (is this a critical medication),
  "durationDays": number (duration in days)
}
]

EXTRACTION RULES:

1. MEDICINE NAME:
   - Extract the exact medicine name as written
   - Include strength/dosage in the name (e.g., "Paracetamol 500mg")
   - Do NOT split combination drugs into separate medicines

2. MEDICINE TYPE:
   - "tablet" for tablets, capsules, pills
   - "syrup" for syrups, suspensions, liquids
   - "other" for injections, drops, ointments, inhalers, etc.

3. INTAKE TIMES (intakeTimes) - CRITICAL RULES:
   - You MUST use ONLY these EXACT strings (case-sensitive):
     * "Before Breakfast"
     * "After Breakfast"
     * "Before Lunch"
     * "After Lunch"
     * "Before Dinner"
     * "After Dinner"
   
   - DO NOT use any other variations or wordings
   - DO NOT use "morning", "afternoon", "evening", "night" - convert them:
     * "morning" or "early morning" → "After Breakfast"
     * "afternoon" or "noon" → "After Lunch"
     * "evening" or "night" → "After Dinner"
     * "empty stomach" or "before food" → "Before Breakfast"
   
   - Common prescription patterns:
     * "1-0-1" means → ["After Breakfast", "After Dinner"]
     * "1-1-1" means → ["After Breakfast", "After Lunch", "After Dinner"]
     * "0-0-1" means → ["After Dinner"]
     * "1-0-0" means → ["After Breakfast"]
     * "0-1-0" means → ["After Lunch"]
     * "2-0-2" with dose 1 → ["After Breakfast", "After Dinner"] with doseCount: 2
     * "1-1-0" means → ["After Breakfast", "After Lunch"]
   
   - Extract ONLY times explicitly mentioned or clearly indicated
   - If unclear, prefer "After Breakfast", "After Lunch", "After Dinner" over "Before"

4. CUSTOM TIMES (customTimes):
   - Use ONLY if specific clock times are mentioned (e.g., "8:00 AM", "2:00 PM")
   - Format: HH:MM in 24-hour format (e.g., "08:00", "14:00", "22:00")
   - Leave empty [] if no specific times mentioned
   - Do NOT add custom times if meal-based times are sufficient

5. DOSE COUNT (doseCount) - CRITICAL ROUNDING RULES:
   - For TABLETS: MUST be a whole number (round to nearest integer)
     * 0.5 → 1
     * 1.5 → 2
     * 2.3 → 2
     * 2.7 → 3
   - For SYRUP: MUST be a multiple of 5 (round to nearest 5ml)
     * 3ml → 5ml
     * 7ml → 5ml
     * 8ml → 10ml
     * 12ml → 10ml
     * 13ml → 15ml
   - For OTHER: use whole numbers, default to 1 if unclear
   - If prescription shows "1-0-1", the doseCount is 1 (not 2)
   - If prescription shows "2-0-2", the doseCount is 2 per intake

6. FREQUENCY:
   - "Daily" if medicine is to be taken every day
   - "Alternate Days" if mentioned (e.g., "on alternate days", "every other day")
   - NOTE: The app does NOT support "Specific Days" - only "Daily" or "Alternate Days"
   - If specific days are mentioned, use "Alternate Days" as closest match

7. DURATION (durationDays):
   - Extract exact duration if mentioned (e.g., "5 days" → 5, "2 weeks" → 14, "1 month" → 30)
   - If "complete the course" → use 7 for general medicines, 5 for antibiotics
   - If unclear, use 7 days as default
   - Must be a positive integer

8. CRITICAL FLAG (isCritical):
   - Set to true if:
     * Prescription mentions "important", "must take", "critical", "do not skip"
     * Antibiotic course (must complete)
     * Prescription explicitly warns not to miss doses
   - Otherwise set to false

VALIDATION CHECKLIST (verify before outputting):
✓ All intakeTimes use EXACT strings: "Before Breakfast", "After Breakfast", "Before Lunch", "After Lunch", "Before Dinner", "After Dinner"
✓ Tablet doseCount is a whole number (1, 2, 3, etc.)
✓ Syrup doseCount is a multiple of 5 (5, 10, 15, 20, etc.)
✓ customTimes are in HH:MM 24-hour format
✓ frequency is one of: "Daily", "Alternate Days"
✓ type is one of: "tablet", "syrup", "other"

IMPORTANT GUIDELINES:
- Extract ONLY what is clearly visible and readable
- Do NOT hallucinate or assume information not present
- Do NOT merge different medicines together
- Do NOT split a single medicine into multiple entries
- If dosage format is unclear, look for common patterns (1-0-1, 1-1-1, etc.)
- If image quality is poor or text is unreadable for a medicine, skip that medicine
- If image is NOT a prescription (e.g., random photo) → return []
- ALWAYS double-check that intakeTimes match the exact required strings

Return ONLY the JSON array, nothing else.
"""
    response = model.generate_content([image, prompt])
    cleaned = _clean_json(response.text)

    try:
        raw = json.loads(cleaned)
        if not isinstance(raw, list):
            return []
    except Exception:
        return []

    medicines = []

    for med in raw:
        med_type = med.get("type", "tablet")
        dose_count = med.get("doseCount", 1 if med_type == "tablet" else 5)
        
        # ENFORCE ROUNDING RULES
        if med_type == "tablet":
            # Round to nearest whole number
            dose_count = round(dose_count)
            if dose_count < 1:
                dose_count = 1
        elif med_type == "syrup":
            # Round to nearest multiple of 5
            dose_count = max(5, round(dose_count / 5) * 5)
        else:
            # Other types: whole numbers
            dose_count = round(dose_count)
            if dose_count < 1:
                dose_count = 1

        # VALIDATE AND FIX INTAKE TIMES
        valid_intake_times = [
            "Before Breakfast", "After Breakfast",
            "Before Lunch", "After Lunch",
            "Before Dinner", "After Dinner"
        ]
        
        intake_times = med.get("intakeTimes", [])
        cleaned_intake_times = []
        
        for time in intake_times:
            # Check if it's already a valid time
            if time in valid_intake_times:
                cleaned_intake_times.append(time)
            else:
                # Try to fix common variations (case-insensitive matching)
                time_lower = time.lower()
                if "before breakfast" in time_lower or "before bf" in time_lower:
                    cleaned_intake_times.append("Before Breakfast")
                elif "after breakfast" in time_lower or "after bf" in time_lower or "morning" in time_lower:
                    cleaned_intake_times.append("After Breakfast")
                elif "before lunch" in time_lower:
                    cleaned_intake_times.append("Before Lunch")
                elif "after lunch" in time_lower or "afternoon" in time_lower or "noon" in time_lower:
                    cleaned_intake_times.append("After Lunch")
                elif "before dinner" in time_lower:
                    cleaned_intake_times.append("Before Dinner")
                elif "after dinner" in time_lower or "evening" in time_lower or "night" in time_lower:
                    cleaned_intake_times.append("After Dinner")
        
        # Remove duplicates while preserving order
        cleaned_intake_times = list(dict.fromkeys(cleaned_intake_times))

        # Force frequency to be only "Daily" or "Alternate Days"
        frequency = med.get("frequency", "Daily")
        if frequency not in ["Daily", "Alternate Days"]:
            frequency = "Daily"

        medicines.append({
            "name": med.get("name", ""),
            "type": med_type,
            "intakeTimes": cleaned_intake_times,
            "customTimes": med.get("customTimes", []),
            "frequency": frequency,
            "doseCount": dose_count,
            "isCritical": med.get("isCritical", False),
            "durationDays": med.get("durationDays", 7)
        })

    return medicines

def extract_medicines(file_bytes: bytes, filename: str) -> List[dict]:
    ext = filename.lower().split(".")[-1]
    all_medicines = []

    # IMAGE
    if ext in ["jpg", "jpeg", "png"]:
        try:
            image = Image.open(io.BytesIO(file_bytes))
            return _extract_from_image(image)
        except Exception as e:
            print(f"Error processing image: {str(e)}")
            return []

    # PDF - Using PyMuPDF (fitz) - NO external dependencies needed!
    if ext == "pdf":
        try:
            import fitz  # PyMuPDF
            
            # Open PDF from bytes
            pdf_document = fitz.open(stream=file_bytes, filetype="pdf")
            
            if pdf_document.page_count == 0:
                print("PDF has no pages")
                pdf_document.close()
                return []
            
            # Process each page
            for page_num in range(pdf_document.page_count):
                try:
                    page = pdf_document[page_num]
                    
                    # Convert page to image (PNG format)
                    # zoom=2 gives 200 DPI (1=100 DPI, 2=200 DPI)
                    mat = fitz.Matrix(2, 2)
                    pix = page.get_pixmap(matrix=mat)
                    
                    # Convert pixmap to PIL Image
                    img_bytes = pix.tobytes("png")
                    image = Image.open(io.BytesIO(img_bytes))
                    
                    # Extract medicines from this page
                    meds = _extract_from_image(image)
                    all_medicines.extend(meds)
                    
                except Exception as e:
                    print(f"Error processing PDF page {page_num + 1}: {str(e)}")
                    continue
            
            pdf_document.close()
            
            # Deduplicate by name
            unique = {}
            for med in all_medicines:
                if med.get("name"):
                    unique[med["name"].lower()] = med

            return list(unique.values())
            
        except Exception as e:
            print(f"Error converting PDF: {str(e)}")
            return []

    return []


@app.post("/api/medicine/extract-file")
async def extract_prescription(file: UploadFile = File(...)):
    try:
        # Validate file type
        if not file.filename:
            raise HTTPException(status_code=400, detail="No filename provided")
        
        ext = file.filename.lower().split(".")[-1]
        if ext not in ["jpg", "jpeg", "png", "pdf"]:
            raise HTTPException(
                status_code=400, 
                detail=f"Unsupported file type: {ext}. Only JPG, PNG, and PDF are supported."
            )
        
        # Read file with size limit (10MB)
        MAX_FILE_SIZE = 10 * 1024 * 1024  # 10MB
        file_bytes = await file.read()
        
        if len(file_bytes) > MAX_FILE_SIZE:
            raise HTTPException(
                status_code=400,
                detail=f"File too large. Maximum size is 10MB."
            )
        
        if len(file_bytes) == 0:
            raise HTTPException(status_code=400, detail="Empty file uploaded")

        medicines = extract_medicines(file_bytes, file.filename)

        if not medicines:
            return JSONResponse(
                content={
                    "success": False,
                    "message": "No valid medicines detected. Please ensure the image/PDF is clear and contains a prescription.",
                    "medicines": []
                },
                status_code=200  # Return 200 even if no medicines found
            )

        return JSONResponse(
            content={
                "success": True,
                "message": f"Successfully extracted {len(medicines)} medicine(s)",
                "medicines": medicines
            }
        )

    except HTTPException:
        raise
    except Exception as e:
        # Log the full error for debugging
        print(f"Unexpected error in extract_prescription: {str(e)}")
        import traceback
        traceback.print_exc()
        
        raise HTTPException(
            status_code=500, 
            detail=f"Error processing file: {str(e)}"
        )

# ===============================
# RUN SERVER
# ===============================
if __name__ == "__main__":
    print("=" * 50)
    print("📸 MediBuddy Prescription Server")
    print("🖼️  Image + 📄 PDF Supported")
    print("=" * 50)
    print("📍 http://0.0.0.0:5002")
    print("🎯 POST /api/medicine/extract-file")
    print("=" * 50)

    uvicorn.run(
        app,
        host="0.0.0.0",
        port=5002,
        log_level="info"
    )
