# python_pipeline/app.py
from flask import Flask, request, jsonify
import google.generativeai as genai
import json
from datetime import datetime, timedelta
import os

app = Flask(__name__)

# Configure Gemini
genai.configure(api_key=os.getenv('AIzaSyA1yGuKhHj88DBdghAWZ8Hp7vUOtKH4EmM'))
model = genai.GenerativeModel('gemini-2.5-flash')

@app.route('/analyze-adherence', methods=['POST'])
def analyze_adherence():
    try:
        data = request.json
        medicines = data.get('medicines', [])
        logs = data.get('logs', [])
        patient_id = data.get('patientId')
        
        # Prepare structured data for Gemini
        analysis_prompt = f"""
You are a medical adherence analyst. Analyze the following patient's medication data and provide:

1. A brief summary paragraph about their overall adherence
2. Timeline data in exact JSON format
3. Medicine-wise adherence data in exact JSON format

PATIENT DATA:
{json.dumps(medicines, indent=2)}

MEDICATION LOGS:
{json.dumps(logs, indent=2)}

IMPORTANT RULES:
- Calculate actual adherence percentages based on taken/missed/delayed counts
- Timeline should cover the last 7 days from today
- Use actual medicine names from the data
- For timeline: morning/afternoon/night should reflect actual log data (use 'taken', 'missed', 'delayed', or 'pending')
- Adherence % = (taken / (taken + missed + delayed)) * 100

OUTPUT FORMAT (respond with valid JSON only):
{{
  "summary": "Your analysis summary here...",
  "timelineData": [
    {{"date": "Jan 18", "morning": "taken", "afternoon": "taken", "night": "taken"}},
    ...more days
  ],
  "medicineData": [
    {{"name": "Medicine Name", "adherence": 95}},
    ...more medicines
  ]
}}

Respond ONLY with the JSON object, no markdown, no extra text.
"""
        
        # Call Gemini
        response = model.generate_content(analysis_prompt)
        
        # Parse Gemini response
        response_text = response.text.strip()
        
        # Remove markdown code blocks if present
        if response_text.startswith('```json'):
            response_text = response_text.replace('```json', '').replace('```', '').strip()
        elif response_text.startswith('```'):
            response_text = response_text.replace('```', '').strip()
        
        # Parse JSON
        result = json.loads(response_text)
        
        # Validate structure
        if not all(key in result for key in ['summary', 'timelineData', 'medicineData']):
            raise ValueError("Invalid response structure from Gemini")
        
        return jsonify(result)
        
    except json.JSONDecodeError as e:
        print(f"JSON Parse Error: {e}")
        print(f"Response was: {response_text}")
        return jsonify({"error": "Failed to parse Gemini response"}), 500
    except Exception as e:
        print(f"Error: {str(e)}")
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(port=5000, debug=True)