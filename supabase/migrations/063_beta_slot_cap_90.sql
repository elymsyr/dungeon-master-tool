-- ============================================================================
-- 063_beta_slot_cap_90.sql — beta slot cap 200 → 90
-- ============================================================================
-- Daha sıkı seçilmiş test grubu için cap düşürülür. IMMUTABLE fonksiyon
-- yeniden CREATE OR REPLACE'lenir — `get_beta_status` ve `join_beta`
-- otomatik yeni değeri okur.
--
-- Mevcut kullanıcı sayısı yeni cap'i aşıyorsa fazla satırlar BU MIGRATION'DA
-- silinmez — fresh start için migration 064 ayrı bir mass-wipe çalıştırır.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.beta_slot_cap()
RETURNS INT LANGUAGE sql IMMUTABLE AS $$ SELECT 90 $$;

NOTIFY pgrst, 'reload schema';
