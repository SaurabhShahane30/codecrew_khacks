import mongoose from "mongoose";

const caretakerSchema = new mongoose.Schema(
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

const Caretaker = mongoose.model("Caretaker", caretakerSchema);
export default Caretaker;