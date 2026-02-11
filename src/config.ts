import dotenv from "dotenv";
dotenv.config();

export const config = {
  botToken: process.env.BOT_TOKEN!,
  webAppUrl: process.env.WEBAPP_URL!,
  supabaseUrl: process.env.SUPABASE_URL!,
  supabaseServiceKey: process.env.SUPABASE_SERVICE_ROLE!,
  isProd: process.env.NODE_ENV === "production"
};
