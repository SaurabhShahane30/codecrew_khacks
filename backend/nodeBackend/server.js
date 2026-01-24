import express from "express";
import mongoose from "mongoose";
import dotenv from "dotenv";

import patientRoutes from "./routes/patientRoutes.js";
import caretakerRoutes from "./routes/caretakerRoutes.js";
// import doctorRoutes from "./routes/doctorRoutes.js";

import medicineRoutes from "./routes/medicineRoutes.js";
import alarmRoutes from "./routes/alarmRoutes.js";

dotenv.config();
const app = express();

app.use(express.json());

// MongoDB connection
mongoose.connect(process.env.MONGO_URI)
  .then(() => console.log("✅ MongoDB connected"))
  .catch(err => console.error("❌ MongoDB error:", err));

app.use("/api/patient", patientRoutes);
app.use("/api/caretaker", caretakerRoutes);
// app.use("/api/doctor", doctorRoutes);

app.use("/api/medicine", medicineRoutes);
app.use("api/alarm", alarmRoutes);

app.listen(5000, () => console.log("🚀 Server running on port 5000"));
