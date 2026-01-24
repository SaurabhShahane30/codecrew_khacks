import Alarm from "../models/Alarm.js";

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

    const now = new Date();

    // current time in minutes since midnight
    const currentMinutes = now.getHours() * 60 + now.getMinutes();

    // -------------------------
    // Fetch all alarms of patient + populate medicine data
    // -------------------------
    const alarms = await Alarm.find({ patientId })
      .populate({
        path: "medicineIds",
        select: "name type doseCount isCritical durationDays"
      });

    // -------------------------
    // Filter alarms for today + after now
    // -------------------------
    const upcomingAlarms = alarms
      .filter(alarm => {
        if (!alarm.time) return false;

        const alarmMinutes = timeToMinutes(alarm.time);
        if (alarmMinutes === null) return false;

        return alarmMinutes > currentMinutes;
      })
      .sort((a, b) => {
        const aMin = timeToMinutes(a.time);
        const bMin = timeToMinutes(b.time);
        return aMin - bMin;
      })
      .map(alarm => ({
        alarmId: alarm._id,
        alarmCode: alarm.alarmCode,
        time: alarm.time,
        isCustom: alarm.isCustom,
        medicines: alarm.medicineIds.map(med => ({
          id: med._id,
          name: med.name,          // ✅ populated
          type: med.type,
          doseCount: med.doseCount,
          isCritical: med.isCritical,
          durationDays: med.durationDays
        }))
      }));

    // -------------------------
    // Response
    // -------------------------
    console.log("Response", upcomingAlarms);
    
    res.json({
      success: true,
      date: now.toISOString().split("T")[0],
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