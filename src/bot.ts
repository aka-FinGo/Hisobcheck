import { Telegraf, Markup } from 'telegraf';
import { config } from './config';
import { getUser, isAdmin } from './services/authService';
import { getAllEmployees, registerRequest, approveEmployee, deleteEmployee } from './services/employeeService';
import { createOrder, getActiveOrders, closeOrder } from './services/orderService';
import { getActiveOrders } from './services/orderService';
import { saveWorkLog, getWorkTypes } from './services/workService';

// VAQTINCHALIK XOTIRA (Kim qaysi zakazni tanlab turibdi?)
interface Draft {
  orderId?: string;
  orderNumber?: string;
  workType?: string;
}
const drafts = new Map<number, Draft>();

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



// ... kodlar davomi ...

// 1. ZAKAZLAR MENU (Admin uchun)
bot.hears('🏗 Zakazlar', async (ctx) => {
  if (!isAdmin(ctx.from.id)) return;

  const orders = await getActiveOrders();
  
  let msg = "📂 <b>Aktiv Zakazlar:</b>\n\n";
  if (orders.length === 0) msg += "Hozircha ochiq zakazlar yo'q.";
  
  orders.forEach((o) => {
    msg += `🔹 <b>${o.order_number}</b> - ${o.client_name}\n`;
  });

  msg += "\n👇 <b>Boshqaruv:</b>\n" +
         "Yangi qo'shish uchun: <code>/zakaz Raqam Mijoz</code>\n" +
         "Yopish uchun: <code>/yopish Raqam</code>";

  ctx.reply(msg, { parse_mode: 'HTML' });
});

// 2. YANGI ZAKAZ QO'SHISH (/zakaz 100_01 Ali aka)
bot.command('zakaz', async (ctx) => {
  if (!isAdmin(ctx.from.id)) return;

  const parts = ctx.message.text.split(' ');
  if (parts.length < 3) {
    return ctx.reply("⚠️ Xato! Format: <code>/zakaz 100_01 Ali aka</code>", { parse_mode: 'HTML' });
  }

  const orderNumber = parts[1];
  const clientName = parts.slice(2).join(' ');

  const result = await createOrder(orderNumber, clientName);

  if (result.error) {
    ctx.reply(`❌ ${result.error}`);
  } else {
    ctx.reply(`✅ <b>${orderNumber}</b> zakazi ochildi! Endi ishchilar unga ish yozishi mumkin.`, { parse_mode: 'HTML' });
  }
});

// 3. ZAKAZNI YOPISH (/yopish 100_01)
bot.command('yopish', async (ctx) => {
  if (!isAdmin(ctx.from.id)) return;

  const parts = ctx.message.text.split(' ');
  if (parts.length < 2) return ctx.reply("Zakaz raqamini yozing. Masalan: /yopish 100_01");

  const orderNumber = parts[1];
  const success = await closeOrder(orderNumber);

  if (success) {
    ctx.reply(`🏁 <b>${orderNumber}</b> zakazi yopildi va arxivlandi.`, { parse_mode: 'HTML' });
  } else {
    ctx.reply("❌ Xatolik. Bunday zakaz topilmadi.");
  }
});
// ------------------------------------------
// ISH YOZISH JARAYONI
// ------------------------------------------

// 1. "📝 Ish yozish" bosilganda -> Zakazlarni chiqarish
bot.hears('📝 Ish yozish', async (ctx) => {
  const orders = await getActiveOrders();

  if (orders.length === 0) {
    return ctx.reply("Hozircha aktiv zakazlar yo'q. Admin zakaz ochishi kerak.");
  }

  // Zakazlarni tugma (Inline Button) qilib chiqaramiz
  const buttons = orders.map(o => [
    Markup.button.callback(`📂 ${o.order_number} (${o.client_name})`, `sel_order_${o.id}_${o.order_number}`)
  ]);

  ctx.reply("Qaysi zakaz bo'yicha ish qildingiz?", Markup.inlineKeyboard(buttons));
});

// 2. Zakaz tanlanganda -> Ish turlarini chiqarish
bot.action(/^sel_order_(.+)_(.+)$/, async (ctx) => {
  const orderId = ctx.match[1];
  const orderNumber = ctx.match[2];
  const userId = ctx.from.id;

  // Xotiraga yozib qo'yamiz
  drafts.set(userId, { orderId, orderNumber });

  // Ish turlarini chiqaramiz
  const workTypes = getWorkTypes();
  const buttons = workTypes.map(wt => [
    Markup.button.callback(`🔨 ${wt}`, `sel_work_${wt}`)
  ]);

  // Eski xabarni o'zgartiramiz
  ctx.editMessageText(
    `Zakaz: <b>${orderNumber}</b>\nEndi qilgan ishingiz turini tanlang:`,
    { 
      parse_mode: 'HTML',
      ...Markup.inlineKeyboard(buttons)
    }
  );
});

// 3. Ish turi tanlanganda -> Miqdorni so'rash
bot.action(/^sel_work_(.+)$/, async (ctx) => {
  const workType = ctx.match[1];
  const userId = ctx.from.id;
  
  const draft = drafts.get(userId);
  if (!draft) return ctx.reply("Xatolik. Iltimos, boshqatdan boshlang.");

  // Xotirani to'ldiramiz
  draft.workType = workType;
  drafts.set(userId, draft);

  ctx.editMessageText(
    `Zakaz: <b>${draft.orderNumber}</b>\n` +
    `Ish: <b>${workType}</b>\n\n` +
    `Qancha ish qildingiz? (Raqam yozing, masalan: 15.5)`,
    { parse_mode: 'HTML' }
  );
});

// 4. Raqam yozilganda -> Bazaga saqlash
bot.on('text', async (ctx) => {
  const userId = ctx.from.id;
  const text = ctx.message.text;
  const draft = drafts.get(userId);

  // Agar bu odam hozir ish yozish jarayonida bo'lmasa, oddiy matn deb qabul qilamiz
  if (!draft || !draft.workType) return;

  // Kiritilgan narsa raqammi?
  // Vergulni nuqtaga aylantiramiz (12,5 -> 12.5)
  const amount = parseFloat(text.replace(',', '.'));

  if (isNaN(amount) || amount <= 0) {
    return ctx.reply("⚠️ Iltimos, to'g'ri raqam yozing (masalan: 10 yoki 12.5).");
  }

  // BAZAGA YOZAMIZ
  const result = await saveWorkLog(userId, draft.orderId!, draft.workType, amount);

  if (result.error) {
    ctx.reply(`❌ Xatolik: ${result.error}`);
  } else {
    // Chiroyli chek chiqaramiz
    const formattedTotal = new Intl.NumberFormat('uz-UZ').format(result.total || 0);
    
    ctx.reply(
      `✅ <b>Qabul qilindi!</b>\n\n` +
      `📂 Zakaz: ${draft.orderNumber}\n` +
      `🔨 Ish: ${draft.workType}\n` +
      `📏 Hajm: ${amount}\n` +
      `💰 Hisoblandi: <b>${formattedTotal} so'm</b>`,
      { parse_mode: 'HTML' }
    );
  }

  // Xotirani tozaylaymiz
  drafts.delete(userId);
});
