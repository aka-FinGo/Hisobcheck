import { bot } from "../bot";

export async function notifyUser(telegramId: number, text: string) {
  try {
    await bot.telegram.sendMessage(telegramId, text);
  } catch (err) {
    console.error("Notification error:", err);
  }
}