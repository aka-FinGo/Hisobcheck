import { FastifyInstance } from "fastify";
import { createPayment } from "../services/paymentService";

export async function paymentRoutes(app: FastifyInstance) {
  app.post("/payments", async (req: any) => {
    return await createPayment(req.body);
  });
}