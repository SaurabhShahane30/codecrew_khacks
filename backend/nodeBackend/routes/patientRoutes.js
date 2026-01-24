import express from "express";
import { authMiddleware, signup, signin, fetchPatientInfo } from "../controllers/patientController.js";

const router = express.Router();

router.get("/", authMiddleware, fetchPatientInfo);

router.post("/signup", signup);
router.post("/signin", signin);

export default router;