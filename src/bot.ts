import { Telegraf, Markup } from 'telegraf';
import { config } from './config';
import { getUser, isAdmin } from './services/authService';
import { createEmployee, getAllEmployees } from './services/employeeService';

export const bot = new Telegraf(config.BOT_TOKEN);

// Admin menyusi
const adminMenu = Markup.keyboard([
  ['👥 Ishchilar', '➕ Ishchi qo\'shish'],
  ['🏗 Zakazlar', '💰 To\'lov qilish'],
  ['📊 Hisobot']
]).resize();

// Ishchi menyusi
const workerMenu = Markup.keyboard([
  ['📝 Ish yozish', '💰 Mening hisobim'],
  ['📞 Admin bilan aloqa']
]).resize();

bot.start(async (ctx) => {
  const userId = ctx.from.id;
  const isSuperAdmin = (userId === config.ADMIN_ID);

  if (isSuperAdmin) {
    return ctx.reply(`👋 Salom, Xo'jayin! \nBoshqaruv paneliga xush kelibsiz.`, adminMenu);
  }

  const user = await getUser(userId);
  
  if (user && user.is_active) {
    return ctx.reply(`👋 Salom, ${user.full_name}! \nIshlaringizga rivoj.`, workerMenu);
  }

  ctx.reply("⛔️ Kechirasiz, siz tizimda yo'qsiz. Admin bilan bog'laning.");
});

// 1. ISHCHI QO'SHISH TUGMASI
bot.hears('➕ Ishchi qo\'shish', async (ctx) => {
  if (!isAdmin(ctx.from.id)) return;
  
  ctx.reply(
    "Yangi ishchi qo'shish uchun quyidagi formatda yozing:\n\n" +
    "👉 `/add Ism Familiya Telefon`\n\n" +
    "Masalan: `/add Ali Valiyev +998901234567`",
    { parse_mode: 'Markdown' }
  );
});

// 2. /add KOMANDASI (Bazaga yozish)
bot.command('add', async (ctx) => {
  if (!isAdmin(ctx.from.id)) return;

  // Xabarni bo'laklaymiz: "/add Ali Valiyev +99890..."
  const parts = ctx.message.text.split(' ');
  
  // Tekshiramiz, yetarli ma'lumot bormi?
  if (parts.length < 3) {
    return ctx.reply("⚠️ Xato format! Iltimos, Ism va Telefonni kiriting.");
  }

  const phone = parts.pop(); // Oxiridagi so'z - telefon deb olamiz
  const name = parts.slice(1).join(' '); // Qolgani - Ism Familiya

  if (!phone || !name) return ctx.reply("Ma'lumotlar chala.");

  ctx.reply("⏳ Bazaga yozilyapti...");

  const result = await createEmployee(name, phone);

  if (result.error) {
    ctx.reply(`❌ Xatolik: ${result.error}`);
  } else {
    ctx.reply(`✅ **${name}** muvaffaqiyatli qo'shildi!\nEndi u botga kirib "Start" bossa, tizim uni taniydi.`);
  }
});

// 3. ISHCHILAR RO'YXATINI KO'RISH
bot.hears('👥 Ishchilar', async (ctx) => {
  if (!isAdmin(ctx.from.id)) return;

  const employees = await getAllEmployees();

  if (employees.length === 0) {
    return ctx.reply("Hozircha ishchilar yo'q.");
  }

  let msg = "👷‍♂️ **Jamoa a'zolari:**\n\n";
  employees.forEach((emp, index) => {
    msg += `${index + 1}. ${emp.full_name} (${emp.phone}) - ${emp.role}\n`;
  });

  ctx.reply(msg, { parse_mode: 'Markdown' });
});

bot.catch((err) => {
  console.log('Bot xatosi:', err);
});
