// backend/routes/reports.js
const express = require('express');
const router = express.Router();
const axios = require('axios');

router.post('/generate-adherence-report/:patientId', async (req, res) => {
  try {
    const { patientId } = req.params;
    
    // Fetch all medicines for this patient from MongoDB
    const medicines = await Medicine.find({ patientId: patientId });
    
    // Fetch medicine logs (taken/missed/delayed records)
    const medicineLogs = await MedicineLog.find({ patientId: patientId });
    
    // Prepare payload for Python pipeline
    const payload = {
      medicines: medicines,
      logs: medicineLogs,
      patientId: patientId
    };
    
    // Call Python pipeline
    const pythonResponse = await axios.post('http://localhost:5000/analyze-adherence', payload);
    
    // Python will return: { summary, timelineData, medicineData }
    res.json(pythonResponse.data);
    
  } catch (error) {
    console.error('Error generating report:', error);
    res.status(500).json({ error: 'Failed to generate report' });
  }
});

module.exports = router;