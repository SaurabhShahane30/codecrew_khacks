import express from "express";
import { getTodayUpcomingAlarms } from "../controllers/alarmController.js";
import { authMiddleware } from "../controllers/patientController.js";

const router = express.Router();

router.get("/upcoming", authMiddleware, getTodayUpcomingAlarms);

export default router;