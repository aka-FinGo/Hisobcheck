import { createClient } from '@supabase/supabase-js';
import { config } from '../config';

// Supabase klientini yaratamiz
export const supabase = createClient(config.SUPABASE_URL, config.SUPABASE_KEY);

// Ulanishni tekshirish uchun kichik funksiya
export const checkConnection = async () => {
  const { data, error } = await supabase.from('employees').select('count').single();
  if (error) {
    console.error('❌ Supabase xatosi:', error.message);
    return false;
  }
  console.log('✅ Supabasega muvaffaqiyatli ulandi!');
  return true;
};
