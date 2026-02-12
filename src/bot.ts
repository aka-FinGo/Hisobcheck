import { Telegraf, Markup } from 'telegraf';
import { config } from './config';
import { getUser, isAdmin } from './services/authService';
import { 
  getAllEmployees, 
  registerRequest, 
  approveEmployee, 
  deleteEmployee, 
  createEmployee 
} from './services/employeeService';
import { createOrder, getActiveOrders, closeOrder } from './services/orderService';
import { saveWorkLog, getWorkTypes } from './services/workService';

// VAQTINCHALIK XOTIRA (Drafts)
interface Draft {
  orderId?: string;
  orderNumber?: string;
  workType?: string;
}
const drafts = new Map<number, Draft>();

export const bot = new Telegraf(config.BOT_TOKEN);

// --- MENYULAR ---
const adminMenu = Markup.keyboard([
  ['👥 Ishchilar', '🏗 Zakazlar'],
  ['📊 Hisobot']
]).resize();

const workerMenu = Markup.keyboard([
  ['📝 Ish yozish', '💰 Mening hisobim'],
  ['📞 Admin bilan aloqa']
]).resize();

// 1. START KOMANDASI
bot.start(async (ctx) => {
  const userId = ctx.from.id;

  if (isAdmin(userId)) {
    return ctx.reply(`👋 Salom, Xo'jayin!`, adminMenu);
  }

  const user = await getUser(userId);

  if (user && user.is_active) {
    return ctx.reply(`👋 Salom, ${user.full_name}! Ishga kirishamizmi?`, workerMenu);
  }

  if (user && !user.is_active) {
    return ctx.reply("⏳ Sizning so'rovingiz Adminga yuborilgan. Tasdiqlashni kuting.");
  }

  ctx.reply(
    "⛔️ Siz tizimda yo'qsiz.\nIshga kirish uchun ro'yxatdan o'ting.",
    Markup.keyboard([
      [Markup.button.contactRequest('📱 Telefon raqamni yuborish')]
    ]).resize()
  );
});

// 2. REGISTRATSIYA (Contact)
bot.on('contact', async (ctx) => {
  const userId = ctx.from.id;
  const contact = ctx.message.contact;

  if (contact.user_id !== userId) {
    return ctx.reply("Iltimos, faqat O'Z raqamingizni yuboring.");
  }

  const fullName = [ctx.from.first_name, ctx.from.last_name].filter(Boolean).join(' ');
  const phone = contact.phone_number.startsWith('+') ? contact.phone_number : `+${contact.phone_number}`;

  const result = await registerRequest(userId, fullName, phone);

  if (result.error) return ctx.reply(`⚠️ ${result.error}`);

  ctx.reply("✅ So'rov yuborildi! Admin tasdiqlashini kuting.", Markup.removeKeyboard());

  bot.telegram.sendMessage(
    config.ADMIN_ID,
    `🔔 <b>Yangi ishchi so'rovi!</b>\n\n👤 ${fullName}\n📱 ${phone}`,
    {
      parse_mode: 'HTML',
      ...Markup.inlineKeyboard([
        [Markup.button.callback('✅ Tasdiqlash', `approve_${userId}`), Markup.button.callback('❌ Rad etish', `reject_${userId}`)]
      ])
    }
  );
});

// 3. ADMIN TASDIQLASHI
bot.action(/approve_(\d+)/, async (ctx) => {
  const userId = parseInt(ctx.match[1]);
  if (await approveEmployee(userId)) {
    ctx.editMessageText(`✅ <b>Qabul qilindi.</b>`, { parse_mode: 'HTML' });
    bot.telegram.sendMessage(userId, "🎉 Tabriklaymiz! Tizimga kirdingiz. /start ni bosing.");
  }
});

bot.action(/reject_(\d+)/, async (ctx) => {
  const userId = parseInt(ctx.match[1]);
  await deleteEmployee(userId);
  ctx.editMessageText(`❌ <b>Rad etildi.</b>`, { parse_mode: 'HTML' });
  bot.telegram.sendMessage(userId, "So'rovingiz rad etildi.");
});

// 4. ISHCHILAR RO'YXATI
bot.hears('👥 Ishchilar', async (ctx) => {
  if (!isAdmin(ctx.from.id)) return;
  const employees = await getAllEmployees();
  
  let msg = "👷‍♂️ <b>Jamoa a'zolari:</b>\n\n";
  employees.forEach((emp, index) => {
    const status = emp.is_active ? "✅" : "⏳";
    msg += `${index + 1}. ${emp.full_name} (<code>${emp.phone}</code>) - ${status}\n`;
  });
  ctx.reply(msg, { parse_mode: 'HTML' });
});

// 5. ZAKAZLAR (Admin)
bot.hears('🏗 Zakazlar', async (ctx) => {
  if (!isAdmin(ctx.from.id)) return;
  const orders = await getActiveOrders();
  
  let msg = "📂 <b>Aktiv Zakazlar:</b>\n\n";
  orders.forEach(o => msg += `🔹 <b>${o.order_number}</b> - ${o.client_name}\n`);
  
  msg += "\nQo'shish: <code>/zakaz 100_01 Ali</code>\nYopish: <code>/yopish 100_01</code>";
  ctx.reply(msg, { parse_mode: 'HTML' });
});

bot.command('zakaz', async (ctx) => {
  if (!isAdmin(ctx.from.id)) return;
  const parts = ctx.message.text.split(' ');
  if (parts.length < 3) return ctx.reply("Xato format.");
  
  const res = await createOrder(parts[1], parts.slice(2).join(' '));
  if (res.error) ctx.reply(`❌ ${res.error}`);
  else ctx.reply(`✅ <b>${parts[1]}</b> ochildi.`, { parse_mode: 'HTML' });
});

bot.command('yopish', async (ctx) => {
  if (!isAdmin(ctx.from.id)) return;
  const parts = ctx.message.text.split(' ');
  if (parts.length < 2) return ctx.reply("Zakaz raqami kerak.");
  
  if (await closeOrder(parts[1])) ctx.reply(`🏁 <b>${parts[1]}</b> yopildi.`, { parse_mode: 'HTML' });
  else ctx.reply("❌ Xatolik.");
});

// 6. ISH YOZISH (Eng muhim qism)
bot.hears('📝 Ish yozish', async (ctx) => {
  const orders = await getActiveOrders();
  if (orders.length === 0) return ctx.reply("Aktiv zakazlar yo'q.");

  const buttons = orders.map(o => [
    Markup.button.callback(`📂 ${o.order_number} (${o.client_name})`, `sel_order_${o.id}_${o.order_number}`)
  ]);
  ctx.reply("Qaysi zakaz?", Markup.inlineKeyboard(buttons));
});

bot.action(/^sel_order_(.+)_(.+)$/, async (ctx) => {
  const [_, orderId, orderNumber] = ctx.match;
  drafts.set(ctx.from.id, { orderId, orderNumber });

  const buttons = getWorkTypes().map(wt => [Markup.button.callback(`🔨 ${wt}`, `sel_work_${wt}`)]);
  ctx.editMessageText(`Zakaz: <b>${orderNumber}</b>\nIsh turini tanlang:`, { 
    parse_mode: 'HTML', 
    ...Markup.inlineKeyboard(buttons) 
  });
});

bot.action(/^sel_work_(.+)$/, async (ctx) => {
  const workType = ctx.match[1];
  const userId = ctx.from.id;
  const draft = drafts.get(userId);
  
  if (!draft) return ctx.reply("Boshqatdan boshlang.");
  
  draft.workType = workType;
  drafts.set(userId, draft);

  ctx.editMessageText(
    `Zakaz: <b>${draft.orderNumber}</b>\nIsh: <b>${workType}</b>\n\nQancha qildingiz? (Raqam yozing)`, 
    { parse_mode: 'HTML' }
  );
});

bot.on('text', async (ctx) => {
  const userId = ctx.from.id;
  const text = ctx.message.text;
  const draft = drafts.get(userId);

  // Agar draft bo'lmasa yoki ishchi menyusida yurgan bo'lsa, javob bermaymiz
  if (!draft || !draft.workType) return;

  const amount = parseFloat(text.replace(',', '.'));
  if (isNaN(amount) || amount <= 0) return ctx.reply("⚠️ Son yozing.");

  const res = await saveWorkLog(userId, draft.orderId!, draft.workType, amount);

  if (res.error) {
    ctx.reply("Xatolik bo'ldi.");
  } else {
    const total = new Intl.NumberFormat('uz-UZ').format(res.total || 0);
    ctx.reply(
      `✅ <b>Yozildi!</b>\n\n📂 ${draft.orderNumber}\n🔨 ${draft.workType}\n💰 <b>${total} so'm</b>`,
      { parse_mode: 'HTML' }
    );
  }
  drafts.delete(userId);
});

bot.catch((err) => console.log('Bot xatosi:', err));
