import Fastify from "fastify";
import { bot } from "./bot";
import dotenv from "dotenv";

dotenv.config();

const app = Fastify();

app.post("/telegram-webhook", async (req, reply) => {
  await bot.handleUpdate(req.body as any);
  reply.send({ ok: true });
});

const start = async () => {
  await bot.telegram.setWebhook(
    `${process.env.RENDER_EXTERNAL_URL}/telegram-webhook`
  );

  await app.listen({
    port: Number(process.env.PORT) || 3000,
    host: "0.0.0.0"
  });

  console.log("Server started");
};

start();
