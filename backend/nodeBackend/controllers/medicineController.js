import Medicine from "../models/medicine.js";
import Alarm from "../models/Alarm.js";
import Patient from "../models/patient.js";

// -------------------------
// Time helpers
// -------------------------

function parseTime12hToMinutes(timeStr) {
  // "09:00 AM" → minutes since midnight
  const [time, meridian] = timeStr.split(" ");
  let [hours, minutes] = time.split(":").map(Number);

  if (meridian === "PM" && hours !== 12) hours += 12;
  if (meridian === "AM" && hours === 12) hours = 0;

  return hours * 60 + minutes;
}

function addMinutes(timeStr, delta) {
  const mins = parseTime12hToMinutes(timeStr);
  return minutesToHHMM(mins + delta);
}

function normalizeMealTimes(mealTimesArr) {
  const obj = {};
  for (const m of mealTimesArr) {
    obj[m.meal] = m.time;
  }
  return obj;
}

function resolveAlarmTime(alarmCode, mealTimesArr) {
  const mealTimes = normalizeMealTimes(mealTimesArr);

  switch (alarmCode) {
    case 1: return addMinutes(mealTimes.breakfast, -15);
    case 2: return addMinutes(mealTimes.breakfast, +30);

    case 3: return addMinutes(mealTimes.lunch, -15);
    case 4: return addMinutes(mealTimes.lunch, +30);

    case 5: return addMinutes(mealTimes.dinner, -15);
    case 6: return addMinutes(mealTimes.dinner, +30);

    default:
      throw new Error("Invalid alarm code");
  }
}

function timeToDeterministicInt32(time) {
  let hash = 0;
  for (let i = 0; i < time.length; i++) {
    hash = (hash << 5) - hash + time.charCodeAt(i);
    hash |= 0; // force 32-bit
  }
  return Math.abs(hash);
}

function minutesToHHMM(minutes) {
 minutes = (minutes + 1440) % 1440; // wrap safely

  let h = Math.floor(minutes / 60);
  const m = minutes % 60;

  const meridian = h >= 12 ? "PM" : "AM";
  h = h % 12;
  if (h === 0) h = 12;

  return `${String(h).padStart(2,"0")}:${String(m).padStart(2,"0")} ${meridian}`;
}

const attachAlarmsToMedicine = async ({
  patientId,
  medicine,
  alarmCodes,
  customTimes,
}) => {
  console.log("🚀 Creating Appropriate Alarm Entries for", patientId);

  const patient = await Patient.findById(patientId);
  if (!patient) throw new Error("Patient not found");

  // ---- Standard meal alarms ----
  for (const code of alarmCodes) {
    const resolvedTime = resolveAlarmTime(code, patient.mealTimes);

    await Alarm.findOneAndUpdate(
      { patientId, alarmCode: code },
      {
        $setOnInsert: {
          patientId,
          alarmCode: code,
          isCustom: false,
          time: resolvedTime,
        },
        $addToSet: {
          medicineIds: medicine._id,
        },
      },
      { upsert: true, new: true }
    );
  }

  // ---- Custom alarms ----
  if (customTimes?.length > 0) {
    for (const time of customTimes) {
      const customCode = timeToDeterministicInt32(time);

      await Alarm.findOneAndUpdate(
        { patientId, alarmCode: customCode },
        {
          $setOnInsert: {
            patientId,
            alarmCode: customCode,
            time,
            isCustom: true,
          },
          $addToSet: {
            medicineIds: medicine._id,
          },
        },
        { upsert: true, new: true }
      );

      medicine.alarmKeys.push(customCode);
    }

    await medicine.save();
  }

  console.log("✅ Alarms attached successfully");
};

/**
 * POST /api/medicine/add
 */
export const addMedicine = async (req, res) => {
  try {
    const patientId = req.user.id;
    console.log("🚀 Backend Hit", patientId);

    const {
      name,
      type,
      intakeTimes = [],
      customTimes = [],
      frequency,
      days,
      startDay,
      doseCount,
      isCritical,
      durationDays,
      photoUrl
    } = req.body;

    // -------------------------
    // Convert intakeTimes → alarmCodes
    // -------------------------
    const ALARM_LABEL_TO_CODE = {
      "Before Breakfast": 1,
      "After Breakfast": 2,
      "Before Lunch": 3,
      "After Lunch": 4,
      "Before Dinner": 5,
      "After Dinner": 6,
    };
    const alarmCodes = [];

    for (const label of intakeTimes) {
      const code = ALARM_LABEL_TO_CODE[label];
      if (!code) {
        return res.status(400).json({
          message: `Invalid intake time: ${label}`,
        });
      }
      alarmCodes.push(code);
    }

    // -------------------------
    // 1. Create Medicine
    // -------------------------
    console.log("🚀 Adding medicine for patient", patientId);

    const medicine = await Medicine.create({ 
      patientId, 
      name, 
      type, 
      alarmKeys: alarmCodes, 
      frequency, 
      days, 
      startDay, 
      doseCount, 
      isCritical, 
      durationDays,
      photoUrl
    });
    console.log("✅ Medicine created:", medicine._id);

    // -------------------------
    // 2. Create / Attach Alarms
    // -------------------------
    await attachAlarmsToMedicine({
      patientId,
      medicine,
      alarmCodes,
      customTimes,
    });

    // -------------------------
    // 3. Response
    // -------------------------
    res.status(201).json({
      success: true,
      message: "Medicine added successfully",
      medicine,
    });

  } catch (error) {
    console.log("❌ Unsuccessfull");
    console.error("Add medicine error:", error);
    res.status(500).json({
      success: false,
      message: "Failed to add medicine",
      error: error.message,
    });
  }
};

/**
 * GET /api/medicine/today
 */
export const fetchTodaysMedicines = async (req, res) => {
  try {
    const patientId = req.user.id;
    console.log("🚀 Fetching Today's medicines for ", patientId);
    
    // -------------------------
    // Date helpers
    // -------------------------
    const today = new Date();

    const dayMap = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    const todayDay = dayMap[today.getDay()]; // e.g. "Thu"

    const startOfToday = new Date(today);
    startOfToday.setHours(0, 0, 0, 0);

    // -------------------------
    // Fetch all medicines of patient
    // -------------------------
    const medicines = await Medicine.find({ patientId });

    const todayMedicines = medicines.filter((med) => {
      // -------------------------
      // Duration check
      // -------------------------
      const createdAt = new Date(med.createdAt);
      const diffDays = Math.floor(
        (startOfToday - new Date(createdAt.setHours(0,0,0,0))) / (1000 * 60 * 60 * 24)
      );

      if (diffDays >= med.durationDays) return false;

      // -------------------------
      // Frequency logic
      // -------------------------
      if (med.frequency === "Daily") {
        return true;
      }

      if (med.frequency === "Specific Days") {
        return med.days.includes(todayDay);
      }

      if (med.frequency === "Alternate Days") {
        // Alternate based on startDay
        const startIndex = dayMap.indexOf(med.startDay);
        const todayIndex = today.getDay();

        const delta =
          Math.abs(todayIndex - startIndex) % 2;

        return delta === 0;
      }

      return false;
    });
    
    res.json({
      success: true,
      date: today.toISOString().split("T")[0],
      day: todayDay,
      count: todayMedicines.length,
      medicines: todayMedicines,
    });

  } catch (error) {
    console.error("Fetch today medicines error:", error);
    res.status(500).json({
      success: false,
      message: "Failed to fetch today's medicines",
      error: error.message,
    });
  }
};
