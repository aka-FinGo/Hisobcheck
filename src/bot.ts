import { Telegraf, Markup } from 'telegraf';
import { config } from './config';
import { getUser, isAdmin } from './services/authService';

export const bot = new Telegraf(config.BOT_TOKEN);

// Admin menyusi
const adminMenu = Markup.keyboard([
  ['👥 Ishchilar', '➕ Ishchi qo\'shish'],
  ['🏗 Zakazlar', '💰 To\'lov qilish'],
  ['📊 Hisobot']
]).resize();

bot.start(async (ctx) => {
  const userId = ctx.from.id;
  
  // 🔍 DIAGNOSTIKA (Muammoni topish uchun)
  // Bu qismni keyin o'chirib tashlaymiz
  await ctx.reply(
    `🔧 Tizim tekshiruvi:\n\n` +
    `👤 Sizning ID: ${userId} (Type: ${typeof userId})\n` +
    `🔑 Admin ID: ${config.ADMIN_ID} (Type: ${typeof config.ADMIN_ID})\n` +
    `✅ Adminmi?: ${userId === config.ADMIN_ID}\n` +
    `-------------------`
  );

  const isSuperAdmin = (userId === config.ADMIN_ID);

  if (isSuperAdmin) {
    return ctx.reply(`👋 Salom, Xo'jayin! \nBoshqaruv paneliga xush kelibsiz.`, adminMenu);
  }

  // Agar admin bo'lmasa, bazadan tekshiramiz
  const user = await getUser(userId);
  
  if (user && user.is_active) {
    return ctx.reply(`👋 Salom, ${user.full_name}!`, Markup.removeKeyboard());
  }

  ctx.reply("⛔️ Kechirasiz, siz tizimda yo'qsiz. ID raqamingiz admin uchun yuqorida ko'rsatildi.");
});

bot.catch((err) => {
  console.log('Bot xatosi:', err);
});
