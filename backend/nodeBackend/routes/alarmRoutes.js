import express from "express";
import { authMiddleware } from "../controllers/patientController.js";
import { getTodayUpcomingAlarms, getAlarmDetailsById, markAlarmTaken, markAlarmDelayed, markAlarmMissed } from "../controllers/alarmController.js";

const router = express.Router();

router.get("/upcoming", authMiddleware, getTodayUpcomingAlarms);
router.get("/details", authMiddleware, getAlarmDetailsById);

router.post("/taken", markAlarmTaken);

// Finish these two routes
router.post("/missed", markAlarmMissed);
router.post("/delayed", markAlarmDelayed);

export default router;