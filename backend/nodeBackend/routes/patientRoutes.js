import express from "express";
import { authMiddleware, signup, signin, fetchPatientInfo, updateMealTimes, addDoctorByCode } from "../controllers/patientController.js";

const router = express.Router();

router.get("/", authMiddleware, fetchPatientInfo);

router.post("/signup", signup);
router.post("/signin", signin);

router.put("/updateTimes", authMiddleware, updateMealTimes);
router.put("/addDoctor", authMiddleware, addDoctorByCode);

export default router;