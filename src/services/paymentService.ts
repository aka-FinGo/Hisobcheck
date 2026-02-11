import { supabase } from "../db/supabase";
import { notifyUser } from "./notifyService";

export async function createPayment(data: any) {
  const { employee_id, amount, currency, description, created_by } = data;

  const { data: settings } = await supabase
    .from("system_settings")
    .select("*")
    .single();

  let status = "pending";

  if (amount <= settings.auto_approve_limit) {
    status = "approved";
  }

  const { data: payment } = await supabase
    .from("payments")
    .insert([
      {
        employee_id,
        amount,
        currency,
        description,
        created_by,
        status
      }
    ])
    .select()
    .single();

  if (status === "approved") {
    const { data: employee } = await supabase
      .from("employees")
      .select("telegram_id")
      .eq("id", employee_id)
      .single();

    await notifyUser(
      employee.telegram_id,
      `Siz nomingizga ${amount} ${currency} yozildi.\nHolati: Tasdiqlandi`
    );
  }

  return payment;
}