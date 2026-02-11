import { supabase } from '../db/supabase';
import { config } from '../config';

// Foydalanuvchi ma'lumotlarini olish
export const getUser = async (telegramId: number) => {
  const { data, error } = await supabase
    .from('employees')
    .select('*')
    .eq('telegram_id', telegramId)
    .single();

  if (error || !data) return null;
  return data;
};

// Admin ekanligini tekshirish (Environment'dagi ID orqali)
export const isAdmin = (telegramId: number) => {
  return telegramId === config.ADMIN_ID;
};
