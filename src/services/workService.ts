import { supabase } from '../db/supabase';

// TARIFLAR (Buni keyinchalik Admin o'zgartira oladigan qilishimiz mumkin)
// Hozircha o'rtacha narxlarni yozib turamiz (So'mda)
const RATES: Record<string, number> = {
  'Loyiha': 5000,    // kv.m
  'Kesish': 2000,    // list
  'Kromka': 1500,    // metr
  'Teshib berish': 1000, // detal
  'Sborka': 4000,    // kv.m
  'Ustanovka': 5000  // kv.m
};

export const getWorkTypes = () => Object.keys(RATES);

export const saveWorkLog = async (telegramId: number, orderId: string, workType: string, amount: number) => {
  // 1. Ishchining ID sini olamiz
  const { data: employee } = await supabase
    .from('employees')
    .select('id')
    .eq('telegram_id', telegramId)
    .single();

  if (!employee) return { error: "Ishchi topilmadi" };

  // 2. Tarifni aniqlaymiz
  const rate = RATES[workType] || 0;
  const total = amount * rate;

  // 3. Bazaga yozamiz
  const { data, error } = await supabase
    .from('work_logs')
    .insert([
      {
        employee_id: employee.id,
        order_id: orderId,
        work_type: workType,
        metric_amount: amount,
        rate: rate,
        // total_amount bazada avtomatik hisoblanadi (generated column)
        // lekin Supabase ba'zida qiymat kutishi mumkin, agar xato bersa shuni qo'shamiz
      }
    ])
    .select()
    .single();

  if (error) {
    console.error("Save Work Error:", error);
    return { error: "Bazaga yozishda xatolik." };
  }

  return { data, total, rate }; // Qancha pul ishlaganini qaytaramiz
};
