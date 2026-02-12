import { Telegraf, Markup } from 'telegraf';
import { config } from './config';
import { getUser, isAdmin } from './services/authService';
import { getAllEmployees, registerRequest, approveEmployee, deleteEmployee } from './services/employeeService';

export const bot = new Telegraf(config.BOT_TOKEN);

// Admin Menyusi
const adminMenu = Markup.keyboard([
  ['👥 Ishchilar', '🏗 Zakazlar'],
  ['📊 Hisobot']
]).resize();

// Ishchi Menyusi
const workerMenu = Markup.keyboard([
  ['📝 Ish yozish', '💰 Mening hisobim'],
  ['📞 Admin bilan aloqa']
]).resize();

// 1. START KOMANDASI
bot.start(async (ctx) => {
  const userId = ctx.from.id;

  // A) Agar Admin bo'lsa
  if (isAdmin(userId)) {
    return ctx.reply(`👋 Salom, Xo'jayin!`, adminMenu);
  }

  // B) Bazani tekshiramiz
  const user = await getUser(userId);

  // Agar ishchi bazada bor va AKTIV bo'lsa
  if (user && user.is_active) {
    return ctx.reply(`👋 Salom, ${user.full_name}! Ishga kirishamizmi?`, workerMenu);
  }

  // Agar ishchi bazada bor, lekin hali TASDIQLANMAGAN bo'lsa
  if (user && !user.is_active) {
    return ctx.reply("⏳ Sizning so'rovingiz Adminga yuborilgan. Iltimos, tasdiqlashini kuting.");
  }

  // C) Agar umuman yangi bo'lsa -> Ro'yxatdan o'tish tugmasi
  ctx.reply(
    "⛔️ Siz tizimda yo'qsiz.\nIshga kirish uchun ro'yxatdan o'ting.",
    Markup.keyboard([
      [Markup.button.contactRequest('📱 Telefon raqamni yuborish')]
    ]).resize()
  );
});

// 2. TELEFON RAQAMNI QABUL QILISH (Avtomatik registratsiya)
bot.on('contact', async (ctx) => {
  const userId = ctx.from.id;
  const contact = ctx.message.contact;

  // Agar birovning kontaktini yuborsa (o'ziniki bo'lmasa)
  if (contact.user_id !== userId) {
    return ctx.reply("Iltimos, pastdagi tugma orqali O'Z raqamingizni yuboring.");
  }

  const fullName = [ctx.from.first_name, ctx.from.last_name].filter(Boolean).join(' ');
  const phone = contact.phone_number.startsWith('+') ? contact.phone_number : `+${contact.phone_number}`;

  // Bazaga "kutilmoqda" statusi bilan yozamiz
  const result = await registerRequest(userId, fullName, phone);

  if (result.error) {
    return ctx.reply(`⚠️ ${result.error}`);
  }

  // Ishchiga javob
  ctx.reply("✅ So'rovingiz qabul qilindi! Admin tasdiqlagach, bot ishga tushadi.", Markup.removeKeyboard());

  // ADMINGA XABAR YUBORAMIZ
  bot.telegram.sendMessage(
    config.ADMIN_ID,
    `🔔 <b>Yangi ishchi so'rovi!</b>\n\n👤 Ism: ${fullName}\n📱 Tel: ${phone}\n\nUni jamoaga qo'shamizmi?`,
    {
      parse_mode: 'HTML',
      ...Markup.inlineKeyboard([
        [
          Markup.button.callback('✅ Tasdiqlash', `approve_${userId}`),
          Markup.button.callback('❌ Rad etish', `reject_${userId}`)
        ]
      ])
    }
  );
});

// 3. ADMIN TASDIQLASHI (Knopkalar logikasi)
bot.action(/approve_(\d+)/, async (ctx) => {
  const userId = parseInt(ctx.match[1]); // ID ni ajratib olamiz
  
  const success = await approveEmployee(userId);
  
  if (success) {
    // Adminga o'zgarish
    ctx.editMessageText(`✅ <b>Qabul qilindi!</b>\nIshchi bazaga qo'shildi.`, { parse_mode: 'HTML' });
    // Ishchiga xabar
    bot.telegram.sendMessage(userId, "🎉 Tabriklaymiz! Siz tizimga qabul qilindingiz.\nBoshlash uchun /start ni bosing.");
  } else {
    ctx.answerCbQuery("Xatolik bo'ldi.");
  }
});

bot.action(/reject_(\d+)/, async (ctx) => {
  const userId = parseInt(ctx.match[1]);
  await deleteEmployee(userId);
  
  ctx.editMessageText(`❌ <b>Rad etildi.</b>`, { parse_mode: 'HTML' });
  bot.telegram.sendMessage(userId, "Afsuski, sizning so'rovingiz rad etildi.");
});

// 4. ISHCHILAR RO'YXATI
bot.hears('👥 Ishchilar', async (ctx) => {
  if (!isAdmin(ctx.from.id)) return;
  const employees = await getAllEmployees();
  
  let msg = "👷‍♂️ <b>Jamoa a'zolari:</b>\n\n";
  employees.forEach((emp, index) => {
    const status = emp.is_active ? "✅" : "⏳ (Kutilmoqda)";
    msg += `${index + 1}. ${emp.full_name} (<code>${emp.phone}</code>) - ${status}\n`;
  });
  ctx.reply(msg, { parse_mode: 'HTML' });
});

bot.catch((err) => {
  console.log('Bot xatosi:', err);
});
