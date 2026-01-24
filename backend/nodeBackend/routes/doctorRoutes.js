import express from "express";
import { authMiddleware } from "../controllers/patientController.js"
import { signup, signin, fetchData } from "../controllers/doctorController.js";

const router = express.Router();

router.get("/", authMiddleware, fetchData);

router.post("/signup", signup);
router.post("/signin", signin);

export default router;