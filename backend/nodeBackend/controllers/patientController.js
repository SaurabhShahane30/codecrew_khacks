import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";

import Patient from "../models/patient.js";
import Caretaker from "../models/caretaker.js";

export const authMiddleware = (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader) return res.status(401).json({ message: "No token" });

    const token = authHeader.split(" ")[1]; // Bearer TOKEN
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    req.user = decoded;
    next();
  } catch (err) {
    return res.status(401).json({ message: "Invalid token" });
  }
};

export const signup = async (req, res) => {
  try {
    const { name, phone, password, caregiverCode  } = req.body;
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

    // CAREGIVER CODE LOGIC

    if (caregiverCode) {
      // Find caretaker by referralCode
      const caretaker = await Caretaker.findOne({ referralCode: caregiverCode });

      if (!caretaker) {
        console.log("❌ Caretaker not found!");
        return res.status(400).json({ message: "Invalid caregiver code" });
      } else {
        // Add patient to caretaker
        caretaker.patients.push(savedPatient._id);
        await caretaker.save();

        console.log(`✅ Patient linked to caretaker ${caretaker.name}`);
      }
    }

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
    console.error("❌ Signup error:", err);
    res.status(500).json({ 
      message: "Server error", 
      error: err.message,
      stack: err.stack
    });
  }

};

export const signin = async (req, res) => {
  try {
    const { phone, password } = req.body;
    console.log("🚀 Signing in user", phone);

    const patient = await Patient.findOne({ phone });
    if (!patient) return res.status(404).json({ message: "Patient not found" });

    const isMatch = await bcrypt.compare(password, patient.password);
    if (!isMatch) {
      console.log("❌ Patient SignIn Failed: Invalid credentials");
      return res.status(400).json({ message: "Invalid credentials" });
    }

    const token = jwt.sign(
      { id: patient._id, phone: patient.phone, name: patient.name },
      process.env.JWT_SECRET,
      { expiresIn: "5h" }
    );
    console.log("✅ New Patient SignIn Successfull");

    res.json({
      token,
      patient: { id: patient._id, phone: patient.phone, name: patient.name }
    });
  } catch (err) {
    console.error("❌ Signup error:", err);
    res.status(500).json({ 
      message: "Server error", 
      error: err.message,
      stack: err.stack
    });
  }
};

export const fetchPatientInfo = async (req, res) => {
  try {
    console.log("🚀 Fetching Info of", req.user.id);

    const patient = await Patient.findById(req.user.id).select('-password');
    if (!patient) return res.status(404).json({ message: 'Patient not found' });
    
    console.log("✅ Patient Info fetched successfully");
    res.json(patient);
  } catch (err) {
    console.log("❌ Fetching unsuccessfull");
    res.status(500).json({ message: 'Server error' });
  }
};