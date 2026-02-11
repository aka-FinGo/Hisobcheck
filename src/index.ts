import { Telegraf } from 'telegraf';
import express from 'express'; // Web server qo'shdik
import { config } from './config';
import { checkConnection } from './db/supabase';

// 1. Botni yaratamiz
const bot = new Telegraf(config.BOT_TOKEN);

// 2. Web serverni yaratamiz (Render uchun shart!)
const app = express();
app.get('/', (req, res) => res.send('Bot is working! 🚀'));

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
    console.log(`Server ${PORT}-portda ishlayapti...`);
});

// Bot komandalari
bot.start(async (ctx) => {
  ctx.reply(`👋 Salom, ${ctx.from.first_name}! \nMen Aristokrat Mebel boshqaruv tizimiman.`);
});

bot.command('status', async (ctx) => {
    const isConnected = await checkConnection();
    if (isConnected) {
        ctx.reply("✅ Tizim: Aloqa a'lo darajada. Baza ulangan.");
    } else {
        ctx.reply("❌ Tizim: Bazaga ulanishda xatolik bor.");
    }
});

bot.catch((err) => {
  console.error('Bot xatosi:', err);
});

// Botni ishga tushirish
bot.launch().then(() => {
    console.log('🚀 Bot ishga tushdi!');
    checkConnection();
});

// Server to'xtatilganda
process.once('SIGINT', () => bot.stop('SIGINT'));
process.once('SIGTERM', () => bot.stop('SIGTERM'));
