import { Telegraf } from "telegraf";
import { config } from "./config";

export const bot = new Telegraf(config.botToken);

bot.start(async (ctx) => {
  await ctx.reply("Payroll Dashboard:", {
    reply_markup: {
      inline_keyboard: [
        [
          {
            text: "📊 Dashboard",
            web_app: { url: config.webAppUrl }
          }
        ]
      ]
    }
  });
});