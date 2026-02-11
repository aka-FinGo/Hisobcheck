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

  // 1️⃣ Limitni olish
  const { data: settings, error: settingsError } = await supabase
    .from("system_settings")
    .select("*")
    .limit(1)
    .single();

  if (settingsError) {
    console.error("Settings fetch error:", settingsError);
    throw new Error("System settings not found");
  }

  const autoApproveLimit = Number(settings?.auto_approve_limit || 0);

  // 2️⃣ Status aniqlash
  let status: "pending" | "approved" = "pending";

  if (amount <= autoApproveLimit) {
    status = "approved";
  }

  // 3️⃣ Payment yozish
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

  if (paymentError) {
    console.error("Payment insert error:", paymentError);
    throw new Error("Payment creation failed");
  }

  // 4️⃣ Agar avtomatik tasdiqlangan bo‘lsa notification yuboramiz
  if (status === "approved") {
    const { data: employee, error: employeeError } = await supabase
      .from("employees")
      .select("telegram_id, full_name")
      .eq("id", employee_id)
      .single();

    if (employeeError) {
      console.error("Employee fetch error:", employeeError);
      return payment;
    }

    if (employee && employee.telegram_id) {
      try {
        await notifyUser(
          employee.telegram_id,
          `💰 Siz nomingizga ${amount} ${currency} yozildi.\n\n` +
          `📝 Izoh: ${description || "—"}\n` +
          `✅ Holati: Tasdiqlandi`
        );
      } catch (notifyError) {
        console.error("Notification error:", notifyError);
      }
    }
  }

  return payment;
}