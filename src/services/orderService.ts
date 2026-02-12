import { supabase } from '../db/supabase';

// 1. Yangi zakaz yaratish
export const createOrder = async (orderNumber: string, clientName: string) => {
  // Avval bormi yo'qmi tekshiramiz
  const { data: existing } = await supabase
    .from('orders')
    .select('id')
    .eq('order_number', orderNumber)
    .single();

  if (existing) {
    return { error: "Bu raqamli zakaz allaqachon mavjud!" };
  }

  const { data, error } = await supabase
    .from('orders')
    .insert([{ order_number: orderNumber, client_name: clientName, status: 'in_progress' }])
    .select()
    .single();

  if (error) return { error: "Bazaga yozishda xatolik." };
  return { data };
};

// 2. Aktiv zakazlarni olish (Ishchilar tanlashi uchun)
export const getActiveOrders = async () => {
  const { data } = await supabase
    .from('orders')
    .select('*')
    .eq('status', 'in_progress') // Faqat tugamaganlari
    .order('created_at', { ascending: false });

  return data || [];
};

// 3. Zakazni yopish (Arxivlash)
export const closeOrder = async (orderNumber: string) => {
  const { error } = await supabase
    .from('orders')
    .update({ status: 'completed' })
    .eq('order_number', orderNumber);

  return !error;
};
