import express from 'express';
import { bot } from './bot'; // 👈 Mana shu qator yangi bot faylini ulaydi!
import { config } from './config';
import { checkConnection } from './db/supabase';

const app = express();
app.get('/', (req, res) => res.send('Bot is working! 🚀'));

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
    console.log(`Server ${PORT}-portda ishlayapti...`);
    console.log(`🔥🔥🔥 YANGI VERSIYA ISHGA TUSHDI 🔥🔥🔥`);
});

// Botni ishga tushirish
bot.launch().then(() => {
    console.log('🚀 Bot ishga tushdi!');
    checkConnection();
});

// Server to'xtatilganda
process.once('SIGINT', () => bot.stop('SIGINT'));
process.once('SIGTERM', () => bot.stop('SIGTERM'));
