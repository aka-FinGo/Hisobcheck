import { supabase } from "../db/supabase";
import { notifyUser } from "./notifyService";

interface CreatePaymentInput {
  employee_id: string;
  amount: number;
  currency: string;
  description?: string;
  created_by: string;
}

export async function createPayment(input: CreatePaymentInput) {
  const { employee_id, amount, currency, description, created_by } = input;

  // 1️⃣ System settings olish
  const { data: settings, error: settingsError } = await supabase
    .from("system_settings")
    .select("auto_approve_limit")
    .limit(1)
    .single();

  if (settingsError || !settings) {
    console.error("Settings fetch error:", settingsError);
    throw new Error("System settings not found");
  }

  const autoApproveLimit = Number(settings.auto_approve_limit || 0);

  // 2️⃣ Yozayotgan user rolini aniqlash
  const { data: creator } = await supabase
    .from("employees")
    .select("role")
    .eq("id", created_by)
    .single();

  let status: "pending" | "approved" = "pending";

  // Admin yozsa doim approved
  if (creator?.role === "admin") {
    status = "approved";
  } else if (amount <= autoApproveLimit) {
    status = "approved";
  }

  // 3️⃣ Payment insert
  const { data: payment, error: paymentError } = await supabase
    .from("payments")
    .insert([
      {
        employee_id,
        amount,
        currency,
        description: description || "",
        created_by,
        status
      }
    ])
    .select()
    .single();

  if (paymentError || !payment) {
    console.error("Payment insert error:", paymentError);
    throw new Error("Payment creation failed");
  }

  // 4️⃣ Notification (faqat approved bo‘lsa)
  if (status === "approved") {
    const { data: employee, error: employeeError } = await supabase
      .from("employees")
      .select("telegram_id, full_name")
      .eq("id", employee_id)
      .single();

    if (!employeeError && employee?.telegram_id) {
      try {
        await notifyUser(
          employee.telegram_id,
          `💰 Siz nomingizga ${amount} ${currency} yozildi.\n\n` +
          `📝 Izoh: ${description || "—"}\n` +
          `✅ Holati: Tasdiqlandi`
        );
      } catch (err) {
        console.error("Notification error:", err);
      }
    }
  }

  return payment;
}