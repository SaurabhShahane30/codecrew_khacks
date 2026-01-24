import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";

import Patient from "../models/patient.js";

export const signup = async (req, res) => {
  try {
    const { name, phone, password } = req.body;
    console.log("🚀 Signing up user", name);

    const existingPatient = await Patient.findOne({ phone });
    if (existingPatient) return res.status(400).json({ message: "Patient already exists" });

    const hashedPassword = await bcrypt.hash(password, 10);

    const newPatient = new Patient({
      name,
      phone,
      password: hashedPassword
    });

    const savedPatient = await newPatient.save();

    const token = jwt.sign(
      { id: savedPatient._id, phone: savedPatient.phone },
      process.env.JWT_SECRET,
      { expiresIn: "5h" }
    );

    console.log("✅ New Patient SignUp Successfull");
    res.json({
      token,
      patient: { id: savedPatient._id, phone: savedPatient.phone, name: savedPatient.name }
    });
  } catch (err) {
    console.log("❌ Signup unsuccessfull");
    res.status(500).json({ message: "Server error", error: err.message });
  }
};

export const signin = async (req, res) => {
  try {
    const { phone, password } = req.body;
    console.log("🚀 Signing in user", phone);

    const patient = await Patient.findOne({ phone });
    if (!patient) return res.status(404).json({ message: "Patient not found" });

    const isMatch = await bcrypt.compare(password, patient.password);
    if (!isMatch) return res.status(400).json({ message: "Invalid credentials" });

    const token = jwt.sign(
      { id: patient._id, phone: patient.phone },
      process.env.JWT_SECRET,
      { expiresIn: "5h" }
    );
    console.log("✅ New Patient SignUp Successfull");

    res.json({
      token,
      patient: { id: patient._id, phone: patient.phone, name: patient.name }
    });
  } catch (err) {
    console.log("❌ Sigin unsuccessfull");
    console.error("Signin error:", err);
    res.status(500).json({ message: "Server error", error: err.message });
  }
};