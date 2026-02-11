import dotenv from 'dotenv';
dotenv.config();

export const config = {
  BOT_TOKEN: process.env.BOT_TOKEN || '',
  SUPABASE_URL: process.env.SUPABASE_URL || '',
  SUPABASE_KEY: process.env.SUPABASE_KEY || '',
  ADMIN_ID: process.env.ADMIN_ID ? parseInt(process.env.ADMIN_ID) : 0
};

if (!config.BOT_TOKEN) {
  throw new Error("⚠️ BOT_TOKEN topilmadi! .env faylni yoki server sozlamalarini tekshiring.");
}
