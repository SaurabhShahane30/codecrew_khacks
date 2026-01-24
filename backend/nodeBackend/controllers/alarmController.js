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