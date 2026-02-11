import { bot } from "../bot";

export async function notifyUser(telegramId: number, text: string) {
  await bot.telegram.sendMessage(telegramId, text);
}
