import { Telegraf, Markup } from 'telegraf';
import { config } from './config';
import { getUser, isAdmin } from './services/authService';

export const bot = new Telegraf(config.BOT_TOKEN);

// 1. Admin Menyusi
const adminMenu = Markup.keyboard([
  ['👥 Ishchilar', '➕ Ishchi qo\'shish'],
  ['🏗 Zakazlar', '💰 To\'lov qilish'],
  ['📊 Hisobot']
]).resize();

// 2. Ishchi Menyusi
const workerMenu = Markup.keyboard([
  ['📝 Ish yozish', '💰 Mening hisobim'],
  ['📞 Admin bilan aloqa']
]).resize();

// 3. /start komandasi
bot.start(async (ctx) => {
  const userId = ctx.from.id;
  const user = await getUser(userId);
  const isSuperAdmin = isAdmin(userId);

  // A) Agar Admin bo'lsa
  if (isSuperAdmin) {
    return ctx.reply(`👋 Salom, Xo'jayin! \nBoshqaruv paneliga xush kelibsiz.`, adminMenu);
  }

  // B) Agar bazada bor ishchi bo'lsa
  if (user && user.is_active) {
    return ctx.reply(`👋 Salom, ${user.full_name}! \nIshlaringizga rivoj.`, workerMenu);
  }

  // C) Agar begona bo'lsa
  ctx.reply("⛔️ Kechirasiz, siz tizimda yo'qsiz. Iltimos, Admin bilan bog'laning.");
});

// 4. Admin funksiyalari (Hozircha shablon)
bot.hears('👥 Ishchilar', async (ctx) => {
  if (!isAdmin(ctx.from.id)) return;
  ctx.reply("Ishchilar ro'yxati tez orada shu yerda bo'ladi...");
});

bot.hears('➕ Ishchi qo\'shish', async (ctx) => {
  if (!isAdmin(ctx.from.id)) return;
  ctx.reply("Yangi ishchi qo'shish uchun: \n/add Ism Familiya Telefon\nko'rinishida yozing. \nMasalan: /add Ali Valiyev +998901234567");
});

// 5. Ishchi funksiyalari (Hozircha shablon)
bot.hears('💰 Mening hisobim', async (ctx) => {
  const user = await getUser(ctx.from.id);
  if (!user) return;
  ctx.reply(`Sizning balansingiz: Hisoblanmoqda...`);
});

bot.catch((err) => {
  console.log('Bot xatosi:', err);
});
