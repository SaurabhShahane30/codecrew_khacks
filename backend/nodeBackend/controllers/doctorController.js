import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import Doctor from "../models/doctor.js";

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
    console.log("🚀 Signing up Doctor", name);

    const existingDoctor = await Doctor.findOne({ phone });
    if (existingDoctor) {
      return res.status(400).json({ message: "Doctor already exists" });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const newDoctor = new Doctor({
      name,
      phone,
      password: hashedPassword,
      patients: []
    });

    await newDoctor.save();

    // ✅ Generate referral code
    const referralCode = generateReferralCode(newDoctor._id);

    // update doctor with referral code
    newDoctor.referralCode = referralCode;
    await newDoctor.save();

    const token = jwt.sign(
      { 
        id: newDoctor._id, 
        phone: newDoctor.phone, 
        code: newDoctor.referralCode 
      },
      process.env.JWT_SECRET,
      { expiresIn: "5h" }
    );

    console.log("✅ New Doctor SignUp Successful");

    res.json({
      token,
      doctor: { 
        id: newDoctor._id,
        name: newDoctor.name,
        phone: newDoctor.phone,
        referralCode: newDoctor.referralCode
      }
    });

  } catch (err) {
    console.error("Doctor signup error:", err);
    res.status(500).json({ 
      message: "Server error", 
      error: err.message 
    });
  }
};

export const signin = async (req, res) => {
  try {
    const { phone, password } = req.body;
    console.log("🚀 Signing In Doctor", phone);

    const doctor = await Doctor.findOne({ phone });
    if (!doctor) {
      return res.status(404).json({ message: "Doctor not found" });
    }

    const isMatch = await bcrypt.compare(password, doctor.password);
    if (!isMatch) {
      console.log("❌ Doctor SignIn Failed: Invalid credentials");
      return res.status(400).json({ message: "Invalid credentials" });
    }

    const token = jwt.sign(
      { id: doctor._id, phone: doctor.phone },
      process.env.JWT_SECRET,
      { expiresIn: "5h" }
    );

    console.log("✅ Doctor SignIn Successful");

    res.json({
      token,
      doctor: {
        id: doctor._id,
        phone: doctor.phone,
        name: doctor.name,
        referralCode: doctor.referralCode
      }
    });

  } catch (err) {
    console.error("Doctor signin error:", err);
    res.status(500).json({ 
      message: "Server error", 
      error: err.message 
    });
  }
};

export const fetchData = async (req, res) => {
  try {
    const doctorId = req.user.id;

    console.log("🚀 Fetching list data for Doctor ID:", doctorId);

    const doctor = await Doctor.findById(doctorId)
      .populate({
        path: "patients",
        select: "name phone"
      });

    if (!doctor) {
      return res.status(404).json({
        success: false,
        message: "Doctor not found"
      });
    }

    res.status(200).json({
      success: true,
      doctor: {
        id: doctor._id,
        name: doctor.name,
        phone: doctor.phone,
        referralCode: doctor.referralCode
      },
      patients: doctor.patients
    });

  } catch (error) {
    console.error("Error fetching doctor data:", error);
    res.status(500).json({
      success: false,
      message: "Server error"
    });
  }
};
