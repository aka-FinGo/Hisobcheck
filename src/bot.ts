import { Telegraf } from 'telegraf';
import { config } from './config';

// Xatolikni tuzatish: config.botToken EMAS, config.BOT_TOKEN
export const bot = new Telegraf(config.BOT_TOKEN);

// Bot ishga tushgandagi xabar
bot.start((ctx) => {
  ctx.reply(`👋 Salom, ${ctx.from.first_name}! \nMen Aristokrat Mebel ERP tizimiman.`);
});

bot.help((ctx) => {
  ctx.reply("Buyruqlar:\n/start - Boshlash\n/status - Tizim holati");
});

// Xatolarni ushlash
bot.catch((err, ctx) => {
  console.log(`Ooops, ${ctx.updateType} da xatolik:`, err);
});
