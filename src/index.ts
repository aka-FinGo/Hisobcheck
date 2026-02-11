import Fastify from "fastify";
import { bot } from "./bot";
import { config } from "./config";
import { paymentRoutes } from "./routes/payments";
import { adminRoutes } from "./routes/admin";
import { dashboardRoutes } from "./routes/dashboard";
import { authRoutes } from "./routes/auth";

const app = Fastify();

app.post("/telegram-webhook", async (req, reply) => {
  await bot.handleUpdate(req.body as any);
  reply.send({ ok: true });
});

app.register(paymentRoutes);
app.register(adminRoutes);
app.register(dashboardRoutes);
app.register(authRoutes);

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