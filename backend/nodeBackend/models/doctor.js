import mongoose from "mongoose";

const doctorSchema = new mongoose.Schema(
  {
    name: { 
      type: String, 
      required: true 
    },
    phone: { 
      type: Number, 
      required: true,
      unique: true 
    },
    password: {
      type: String,
      required: true
    },
    referralCode: {
      type: String,
      unique: true,
      index: true
    },
    patients: [{ 
      type: mongoose.Schema.Types.ObjectId, 
      ref: "Patient" 
    }]
  },
  { timestamps: true }
);

const Doctor = mongoose.model("Doctor", doctorSchema);
export default Doctor;