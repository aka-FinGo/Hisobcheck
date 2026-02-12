import { supabase } from '../db/supabase';

// Yangi ishchi yaratish
export const createEmployee = async (fullName: string, phone: string, role: string = 'worker') => {
  // Avval bunday telefon raqam borligini tekshiramiz
  const { data: existing } = await supabase
    .from('employees')
    .select('id')
    .eq('phone', phone)
    .single();

  if (existing) {
    return { error: "Bu telefon raqam allaqachon ro'yxatdan o'tgan!" };
  }

  // Yo'q bo'lsa, yangi qo'shamiz
  const { data, error } = await supabase
    .from('employees')
    .insert([
      {
        full_name: fullName,
        phone: phone,
        role: role,
        is_active: true
      }
    ])
    .select()
    .single();

  if (error) {
    console.error('Create Employee Error:', error);
    return { error: "Bazaga yozishda xatolik bo'ldi." };
  }

  return { data };
};

// Barcha ishchilarni olish (Ro'yxat uchun)
export const getAllEmployees = async () => {
  const { data, error } = await supabase
    .from('employees')
    .select('*')
    .order('created_at', { ascending: false });

  return data || [];
};
