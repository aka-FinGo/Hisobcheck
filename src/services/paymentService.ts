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

  const { data: employee, error } = await supabase
  .from("employees")
  .select("telegram_id")
  .eq("id", employee_id)
  .single();

if (error) {
  console.error("Employee fetch error:", error);
  return payment;
}

if (employee && employee.telegram_id) {
  await notifyUser(
    employee.telegram_id,
    `Siz nomingizga ${amount} ${currency} yozildi.\nHolati: Tasdiqlandi`
  );
}

  return payment;
}