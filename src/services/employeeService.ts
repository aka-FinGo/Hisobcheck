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
// ... tepadagi kodlar qoladi ...

// Ishchini tasdiqlash (Active = true qilish)
export const approveEmployee = async (telegramId: number) => {
  const { error } = await supabase
    .from('employees')
    .update({ is_active: true })
    .eq('telegram_id', telegramId);

  if (error) return false;
  return true;
};

// Ishchini o'chirib tashlash (Rad etish)
export const deleteEmployee = async (telegramId: number) => {
    const { error } = await supabase
      .from('employees')
      .delete()
      .eq('telegram_id', telegramId);
  
    if (error) return false;
    return true;
  };

// Telegram ID orqali yangi ishchi yaratish (Statusi: nofaol)
export const registerRequest = async (telegramId: number, fullName: string, phone: string) => {
    // Avval borligini tekshiramiz
    const { data: existing } = await supabase
        .from('employees')
        .select('*')
        .eq('telegram_id', telegramId)
        .single();

    if (existing) {
        return { error: "Siz allaqachon ro'yxatdan o'tgansiz." };
    }

    // Yangi qo'shamiz (Lekin is_active: false bo'ladi)
    const { data, error } = await supabase
        .from('employees')
        .insert([
            {
                full_name: fullName,
                phone: phone,
                telegram_id: telegramId,
                role: 'worker',
                is_active: false // <--- DIQQAT: Admin tasdiqlamaguncha ishlamaydi
            }
        ])
        .select()
        .single();

    if (error) return { error: "Xatolik bo'ldi." };
    return { data };
};
