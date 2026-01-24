import Alarm from "../models/Alarm.js";
import Medicine from "../models/medicine.js";

function timeToMinutes(timeStr) {
  if (!timeStr) return null;

  // Supports "HH:MM" and "H:MM AM/PM"
  if (timeStr.includes("AM") || timeStr.includes("PM")) {
    const [time, meridian] = timeStr.split(" ");
    let [h, m] = time.split(":").map(Number);

    if (meridian === "PM" && h !== 12) h += 12;
    if (meridian === "AM" && h === 12) h = 0;

    return h * 60 + m;
  }

  // 24-hour format
  const [h, m] = timeStr.split(":").map(Number);
  return h * 60 + m;
}

export const getTodayUpcomingAlarms = async (req, res) => {
  try {
    const patientId = req.user.id;
    console.log("🚀 Fetch Today's Upcoming Alarms for", patientId);

    const now = new Date();
    const today = `${now.getFullYear()}-${String(now.getMonth()+1).padStart(2,'0')}-${String(now.getDate()).padStart(2,'0')}`;

    const currentMinutes = now.getHours() * 60 + now.getMinutes();

    const alarms = await Alarm.find({ patientId }).populate({
      path: "medicines.medicineId",
      select: "name type doseCount isCritical durationDays"
    });

    const upcomingAlarms = alarms
      .map(alarm => {
        const alarmMinutes = timeToMinutes(alarm.time);
        if (alarmMinutes === null || alarmMinutes <= currentMinutes) return null;

        // medicines active today
        const todaysMeds = alarm.medicines
          .filter(m => m.dates.includes(today))
          .map(m => ({
            id: m.medicineId._id,
            name: m.medicineId.name,
            type: m.medicineId.type,
            doseCount: m.medicineId.doseCount,
            isCritical: m.medicineId.isCritical,
            durationDays: m.medicineId.durationDays
          }));

        if (todaysMeds.length === 0) return null;

        return {
          alarmId: alarm._id,
          alarmCode: alarm.alarmCode,
          time: alarm.time,
          isCustom: alarm.isCustom,
          medicines: todaysMeds
        };
      })
      .filter(Boolean)
      .sort((a, b) => timeToMinutes(a.time) - timeToMinutes(b.time));

    console.log("✅ Upcoming alarms fetched:", upcomingAlarms);

    res.json({
      success: true,
      date: today,
      currentTime: now.toTimeString().slice(0,5),
      count: upcomingAlarms.length,
      alarms: upcomingAlarms
    });

  } catch (error) {
    console.error("Fetch upcoming alarms error:", error);
    res.status(500).json({
      success: false,
      message: "Failed to fetch upcoming alarms",
      error: error.message
    });
  }
};

export const getAlarmDetailsById = async (req, res) => {
  try {
    const { id: alarmId } = req.query;

    console.log("🚀 Fetching alarm details for ID:", alarmId);

    if (!alarmId) {
      return res.status(400).json({
        success: false,
        message: "alarmId query param is required",
      });
    }

    console.log("🚀 Fetching alarm medicines details:", alarmId);

    const alarm = await Alarm.findOne({
      _id: alarmId
    }).populate({
      path: "medicines.medicineId",
    });

    if (!alarm) {
      return res.status(404).json({
        success: false,
        message: "Alarm not found",
      });
    }

    // 🔁 Format response
    const medicines = alarm.medicines.map(m => {
      const med = m.medicineId;

      return {
        id: med._id,
        name: med.name,
        type: med.type,
        frequency: med.frequency,
        durationDays: med.durationDays,
        doseCount: med.doseCount,
        taken: med.taken,
        missed: med.missed,
        delayed: med.delayed,
        isCritical: med.isCritical,
        photoUrl: med.photoUrl,
        scheduleDates: m.dates,   // ✅ per-medicine dates
        createdAt: med.createdAt,
        updatedAt: med.updatedAt
      };
    });

    const response = {
        alarmId: alarm._id,
        alarmCode: alarm.alarmCode,
        time: alarm.time,
        isCustom: alarm.isCustom,
        createdAt: alarm.createdAt,
        updatedAt: alarm.updatedAt,
        medicines
      } 

    console.log("✅ Alarm Medicines fetched:", response);

    res.json({
      success: true,
      alarm: {
        alarmId: alarm._id,
        alarmCode: alarm.alarmCode,
        time: alarm.time,
        isCustom: alarm.isCustom,
        createdAt: alarm.createdAt,
        updatedAt: alarm.updatedAt,
        medicines
      }
    });

  } catch (error) {
    console.error("❌ Fetch alarm details error:", error);
    res.status(500).json({
      success: false,
      message: "Failed to fetch alarm details",
      error: error.message
    });
  }
};

export const markAlarmTaken = async (req, res) => {
  try {
    const { alarmId } = req.body;

    console.log("🚀 Marking alarm as taken:", alarmId);

    if (!alarmId) {
      return res.status(400).json({
        success: false,
        message: "alarmId is required",
      });
    }

    const alarm = await Alarm.findOne({ _id: alarmId });

    if (!alarm) {
      return res.status(404).json({
        success: false,
        message: "Alarm not found",
      });
    }

    const medicineIds = alarm.medicines.map(m => m.medicineId);

    await Medicine.updateMany(
      { _id: { $in: medicineIds } },
      { $inc: { taken: 1 } }
    );

    console.log("✅ Medicines marked as taken for alarm:");

    res.json({
      success: true,
      message: "Medicines marked as taken",
      alarmId,
      count: medicineIds.length
    });

  } catch (error) {
    console.error("❌ Mark taken error:", error);
    res.status(500).json({
      success: false,
      message: "Failed to mark alarm as taken",
      error: error.message
    });
  }
};

export const markAlarmMissed = async (req, res) => {
  try {
    const { alarmId } = req.body;

    console.log("🚀 Marking alarm as missed:", alarmId);

    if (!alarmId) {
      return res.status(400).json({
        success: false,
        message: "alarmId is required",
      });
    }

    const alarm = await Alarm.findOne({ _id: alarmId });

    if (!alarm) {
      return res.status(404).json({
        success: false,
        message: "Alarm not found",
      });
    }

    const medicineIds = alarm.medicines.map(m => m.medicineId);

    await Medicine.updateMany(
      { _id: { $in: medicineIds } },
      { $inc: { missed: 1 } }
    );

    console.log("✅ Medicines marked as missed for alarm:");

    res.json({
      success: true,
      message: "Medicines marked as missed",
      alarmId,
      count: medicineIds.length
    });

  } catch (error) {
    console.error("❌ Mark missed error:", error);
    res.status(500).json({
      success: false,
      message: "Failed to mark alarm as missed",
      error: error.message
    });
  }
};

export const markAlarmDelayed = async (req, res) => {
  try {
    const { alarmId } = req.body;

    console.log("🚀 Marking alarm as delayed:", alarmId);

    if (!alarmId) {
      return res.status(400).json({
        success: false,
        message: "alarmId is required",
      });
    }

    const alarm = await Alarm.findOne({ _id: alarmId });

    if (!alarm) {
      return res.status(404).json({
        success: false,
        message: "Alarm not found",
      });
    }

    const medicineIds = alarm.medicines.map(m => m.medicineId);

    await Medicine.updateMany(
      { _id: { $in: medicineIds } },
      { $inc: { delayed: 1 } }
    );

    console.log("✅ Medicines marked as delayed for alarm:", alarmId);

    res.json({
      success: true,
      message: "Medicines marked as delayed",
      alarmId,
      count: medicineIds.length
    });

  } catch (error) {
    console.error("❌ Mark delayed error:", error);
    res.status(500).json({
      success: false,
      message: "Failed to mark alarm as delayed",
      error: error.message
    });
  }
};
