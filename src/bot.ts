import { Telegraf } from "telegraf";

export const bot = new Telegraf(process.env.BOT_TOKEN!);

bot.start(async (ctx) => {
  await ctx.reply("Dashboardni ochish:", {
    reply_markup: {
      inline_keyboard: [
        [
          {
            text: "📊 Dashboard",
            web_app: { url: process.env.WEBAPP_URL! }
          }
        ]
      ]
    }
  });
});
