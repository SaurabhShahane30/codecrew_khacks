import mongoose from "mongoose";

const AlarmSchema = new mongoose.Schema(
  {
    patientId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Patient",
      required: true,
    },

    alarmCode: {
      type: Number, // 1–6 = meal based or custom hashed code
      required: true,
    },

    time: {
      type: String, // "HH:MM AM/PM"
      required: true,
    },

    isCustom: {
      type: Boolean,
      default: false,
    },

    medicineIds: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: "Medicine",
      },
    ],

    dates: [
      {
        type: String, // "YYYY-MM-DD"
      },
    ],
  },
  { timestamps: true }
);

AlarmSchema.index({ patientId: 1, alarmCode: 1 }, { unique: true });

export default mongoose.model("Alarm", AlarmSchema);