import { Telegraf } from 'telegraf';
import { config } from './config';
import { checkConnection } from './db/supabase';

// Botni yaratamiz
const bot = new Telegraf(config.BOT_TOKEN);

// Bot ishga tushganda
bot.start(async (ctx) => {
  ctx.reply(`👋 Salom, ${ctx.from.first_name}! \nMen Aristokrat Mebel boshqaruv tizimiman.`);
});

// Bazani tekshirish komandasi
bot.command('status', async (ctx) => {
    const isConnected = await checkConnection();
    if (isConnected) {
        ctx.reply("✅ Tizim: Aloqa a'lo darajada. Baza ulangan.");
    } else {
        ctx.reply("❌ Tizim: Bazaga ulanishda xatolik bor.");
    }
});

// Xatoliklarni ushlash
bot.catch((err) => {
  console.error('Bot xatosi:', err);
});

// Botni ishga tushirish
bot.launch().then(() => {
    console.log('🚀 Bot ishga tushdi!');
    checkConnection();
});

// Server to'xtatilganda botni chiroyli o'chirish
process.once('SIGINT', () => bot.stop('SIGINT'));
process.once('SIGTERM', () => bot.stop('SIGTERM'));
