import express from "express";
import { authMiddleware } from "../controllers/patientController.js"
import { signup, signin, fetchCaretakerInfo, addMedicine, getAlerts } from "../controllers/caretakerController.js";

const router = express.Router();

router.get("/", authMiddleware, fetchCaretakerInfo);
router.get("/alerts", authMiddleware, getAlerts);

router.post("/signup", signup);
router.post("/signin", signin);
router.post("/add", addMedicine);

export default router;