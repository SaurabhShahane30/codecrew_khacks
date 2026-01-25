import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import Caretaker from "../models/caretaker.js";

import Medicine from "../models/medicine.js";
import Alarm from "../models/Alarm.js";
import Patient from "../models/patient.js";

const generateReferralCode = (objectId) => {
  // take last 8 chars of ObjectId
  const lastPart = objectId.toString().slice(-8);

  // convert hex → int → base36 → uppercase
  const base36 = parseInt(lastPart, 16).toString(36).toUpperCase();

  // ensure 6 chars
  return base36.slice(0, 6).padStart(6, "0");
};

export const signup = async (req, res) => {
  try {    
    const { name, phone, password } = req.body;
    console.log("🚀 Signing up Caretaker", name);

    const existingCaretaker = await Caretaker.findOne({ phone });
    if (existingCaretaker) {
      return res.status(400).json({ message: "Caretaker already exists" });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const newCaretaker = new Caretaker({
      name,
      phone,
      password: hashedPassword,
      patients: []
    });

    await newCaretaker.save();

    // ✅ Generate referral code
    const referralCode = generateReferralCode(newCaretaker._id);

    // update caretaker with referral code
    newCaretaker.referralCode = referralCode;
    await newCaretaker.save();

    const token = jwt.sign(
        { id: newCaretaker._id, phone: newCaretaker.phone, referralCode: newCaretaker.referralCode },
        process.env.JWT_SECRET,
        { expiresIn: "5h" }
    );

    console.log("✅ New Caretaker SignUp Successfull");
    res.json({
      token,
      caretaker: { 
        id: newCaretaker._id,
        name: newCaretaker.name,
        phone: newCaretaker.phone,
        referralCode: newCaretaker.referralCode
     }
    });
  } catch (err) {
    res.status(500).json({ 
      message: "Server error", 
      error: err.message 
    });
  }
};

export const signin = async (req, res) => {
  try {
    const { phone, password } = req.body;
    console.log("🚀 Signing In Caretaker", phone);

    const caretaker = await Caretaker.findOne({ phone });
    if (!caretaker) {
      return res.status(404).json({ message: "Caretaker not found" });
    }

    const isMatch = await bcrypt.compare(password, caretaker.password);
    if (!isMatch) {
      console.log("❌ Caretaker SignIn Failed: Invalid credentials");
      return res.status(400).json({ message: "Invalid credentials" });
    }

    const token = jwt.sign(
        { id: caretaker._id, phone: caretaker.phone },
        process.env.JWT_SECRET,
        { expiresIn: "5h" }
    );

    console.log("✅ New Caretaker SignIn Successfull");
    res.json({
      token,
      caretaker: {
        id: caretaker._id,
        phone: caretaker.phone,
        name: caretaker.name
      }
    });

  } catch (err) {
    console.error("Caretaker signin error:", err);
    res.status(500).json({ 
      message: "Server error", 
      error: err.message 
    });
  }
};

export const fetchCaretakerInfo = async (req, res) => {
  try {
    const caretakerId = req.user.id;

    const caretaker = await Caretaker.findById(caretakerId)
      .populate({
        path: "patients",
        select: "name phone mealTimes createdAt" // only required fields
      });

    if (!caretaker) {
      return res.status(404).json({
        success: false,
        message: "Caretaker not found"
      });
    }

    const xx = { caretaker: {
        id: caretaker._id,
        name: caretaker.name,
        phone: caretaker.phone,
        referralCode: caretaker.referralCode
      },
      patients: caretaker.patients };
    console.log(xx);
    

    res.status(200).json({
      success: true,
      caretaker: {
        id: caretaker._id,
        name: caretaker.name,
        phone: caretaker.phone,
        referralCode: caretaker.referralCode
      },
      patients: caretaker.patients
    });

  } catch (error) {
    console.error("Error fetching caretaker patients:", error);
    res.status(500).json({
      success: false,
      message: "Server error"
    });
  }
};

export const getAlerts = async (req, res) => {
  try {
    const caretakerId = req.user.id; // or req.user.id if using auth middleware

    if (!caretakerId) {
      return res.status(400).json({
        success: false,
        message: "caretakerId is required",
      });
    }

    // 1️⃣ Find caretaker
    const caretaker = await Caretaker.findById(caretakerId).lean();

    if (!caretaker) {
      return res.status(404).json({
        success: false,
        message: "Caretaker not found",
      });
    }

    // 2️⃣ Get patient IDs
    const patientIds = caretaker.patients || [];

    if (patientIds.length === 0) {
      return res.json({
        success: true,
        alerts: [],
        message: "No patients linked to caretaker",
      });
    }

    // 3️⃣ Find medications with missed > 0
    const alerts = await Medicine.find({
      patientId: { $in: patientIds },
      missed: { $gt: 0 }
    })
    .populate("patientId", "name phone") // optional
    .lean();

    // 4️⃣ Response
    res.json({
      success: true,
      count: alerts.length,
      alerts
    });

  } catch (error) {
    console.error("❌ getAlerts error:", error);
    res.status(500).json({
      success: false,
      message: "Failed to fetch alerts",
      error: error.message
    });
  }
};







// -------------------------
// Add Medicine and Alarm
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
function convert24hTo12h(time24) {
  // "18:30" → "06:30 PM"
  let [h, m] = time24.split(":").map(Number);

  const meridian = h >= 12 ? "PM" : "AM";
  h = h % 12;
  if (h === 0) h = 12;

  return `${String(h).padStart(2, "0")}:${String(m).padStart(2, "0")} ${meridian}`;
}
function formatDate(date) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}
function addDays(date, days) {
  const d = new Date(date);
  d.setDate(d.getDate() + days);
  return d;
}
function generateDailyDates(startDate, durationDays) {
  const dates = [];
  for (let i = 0; i < durationDays; i++) {
    dates.push(formatDate(addDays(startDate, i)));
  }
  return dates;
}
function generateAlternateDates(startDate, doseCount) {
  const dates = [];
  let currentDate = new Date(startDate);

  for (let i = 0; i < doseCount; i++) {
    dates.push(formatDate(currentDate));
    currentDate = addDays(currentDate, 2); // 🔁 jump 2 days
  }

  return dates;
}
function generateSpecificDayDates(startDate, durationDays, allowedDays) {
  const dates = [];
  let current = new Date(startDate);

  const dayMap = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"];

  for (let i = 0; i < durationDays; i++) {
    const day = dayMap[current.getDay()];
    if (allowedDays.includes(day)) {
      dates.push(formatDate(current));
    }
    current = addDays(current, 1);
  }

  return dates;
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

  const startDate = new Date(); // always today
  let dates = [];

  if (medicine.frequency === "Daily") {
    dates = generateDailyDates(startDate, medicine.durationDays);
  }

  if (medicine.frequency === "Alternate Days") {
    dates = generateAlternateDates(startDate, medicine.durationDays);
  }

  if (medicine.frequency === "Specific Days") {
    dates = generateSpecificDayDates(
      startDate,
      medicine.durationDays,
      medicine.days
    );
  }

  // ---------------- Standard alarms ----------------
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
        $push: {
          medicines: {
            medicineId: medicine._id,
            dates: dates
          }
        }
      },
      { upsert: true }
    );
  }

  // ---------------- Custom alarms ----------------
  if (customTimes?.length > 0) {
    for (const time of customTimes) {
      const time12h = time.includes("AM") || time.includes("PM")
        ? time
        : convert24hTo12h(time);

      const customCode = timeToDeterministicInt32(time12h);

      await Alarm.findOneAndUpdate(
        { patientId, alarmCode: customCode },
        {
          $setOnInsert: {
            patientId,
            alarmCode: customCode,
            time: time12h,
            isCustom: true,
          },
          $push: {
            medicines: {
              medicineId: medicine._id,
              dates: dates
            }
          }
        },
        { upsert: true }
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
     const patientId = req.body.patientId
    console.log("🚀 Add Medicine Backend Hit", patientId);

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
    console.log("✅ Medicine created", medicine._id);

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