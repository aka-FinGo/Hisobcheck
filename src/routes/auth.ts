import { FastifyInstance } from "fastify";

export async function authRoutes(app: FastifyInstance) {
  app.get("/health", async () => {
    return { status: "OK" };
  });
}