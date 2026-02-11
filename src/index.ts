import Fastify from "fastify";
import { config } from "./config";
import { registerWebhook, setTelegramWebhook } from "./webhook";
import { paymentRoutes } from "./routes/payments";
import { adminRoutes } from "./routes/admin";
import { dashboardRoutes } from "./routes/dashboard";
import { authRoutes } from "./routes/auth";

const app = Fastify({ logger: true });

app.register(authRoutes);
app.register(paymentRoutes);
app.register(adminRoutes);
app.register(dashboardRoutes);

registerWebhook(app);

const start = async () => {
  await app.listen({
    port: config.port,
    host: "0.0.0.0"
  });

  await setTelegramWebhook();

  console.log("🚀 Server started");
};

start();