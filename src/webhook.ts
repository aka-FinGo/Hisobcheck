import { FastifyInstance } from "fastify";
import { bot } from "./bot";

export async function registerWebhook(app: FastifyInstance) {
  // Telegram update qabul qilish endpoint
  app.post("/telegram-webhook", async (req, reply) => {
    try {
      await bot.handleUpdate(req.body as any);
      reply.send({ ok: true });
    } catch (err) {
      console.error("Webhook error:", err);
      reply.status(500).send({ error: "Webhook failed" });
    }
  });
}

export async function setTelegramWebhook() {
  const webhookUrl = `${process.env.RENDER_EXTERNAL_URL}/telegram-webhook`;

  await bot.telegram.setWebhook(webhookUrl);

  console.log("Webhook set to:", webhookUrl);
}