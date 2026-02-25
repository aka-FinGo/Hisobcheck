-- 1. app_roles jadvali uchun xavfsizlikni (RLS) yoqamiz
ALTER TABLE public.app_roles ENABLE ROW LEVEL SECURITY;

-- 2. Dasturga kirgan har bir xodim rollar ro'yxatini ko'ra olishi kerak (SELECT)
CREATE POLICY "Hamma rollarni ko'ra oladi" 
ON public.app_roles FOR SELECT 
USING (auth.role() = 'authenticated');

-- 3. YANGI ROL QO'SHISH (INSERT) - Faqat Super Admin (siz) uchun
CREATE POLICY "Faqat super admin rol qo'sha oladi" 
ON public.app_roles FOR INSERT 
WITH CHECK (
  EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = auth.uid() AND is_super_admin = true)
);

-- 4. ROLLARI TAHRIRLASH (UPDATE) - Faqat Super Admin uchun
CREATE POLICY "Faqat super admin rol o'zgartira oladi" 
ON public.app_roles FOR UPDATE 
USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = auth.uid() AND is_super_admin = true)
);

-- 5. ROLLARNI O'CHIRISH (DELETE) - Faqat Super Admin uchun
CREATE POLICY "Faqat super admin rolni o'chira oladi" 
ON public.app_roles FOR DELETE 
USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = auth.uid() AND is_super_admin = true)
);
