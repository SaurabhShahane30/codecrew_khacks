import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import Caretaker from "../models/caretaker.js";

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
        { id: newCaretaker._id, phone: newCaretaker.phone, code: newCaretaker.referralCode },
        process.env.JWT_SECRET,
        { expiresIn: "5h" }
    );

    console.log("✅ New Caretaker SignUp Successfull");
    res.json({
      token,
      caretaker: { id: newCaretaker._id,
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

    res.status(200).json({
      success: true,
      caretaker: {
        id: caretaker._id,
        name: caretaker.name,
        phone: caretaker.phone,
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
