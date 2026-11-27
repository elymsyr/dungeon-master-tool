-- ============================================================================
-- 111_guest_notifications.sql
--   Kayıtsız (misafir, `anon`) kullanıcı da yayınlanmış bildirimleri görür.
--   • list_notifications(): auth.uid() NULL iken erken dönmez; user'a bağlı
--     LEFT JOIN'ler eşleşmez → my_answers NULL, read false, dismiss yok.
--     Misafirin okundu/temizle durumu cihazda tutulur (client).
--   • anon'a yalnız bu RPC açılır; notifications tablosuna anon SELECT
--     verilmez (081'in dar anon yüzeyi korunur, created_by dışarı çıkmaz).
--   • submit/mark_read/dismiss uid ister, anon için değişmez (no-op/FALSE).
-- ============================================================================

CREATE OR REPLACE FUNCTION public.list_notifications()
RETURNS TABLE (
  id         UUID,
  title      TEXT,
  blocks     JSONB,
  created_at TIMESTAMPTZ,
  my_answers JSONB,
  read       BOOLEAN
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_user UUID := auth.uid();
BEGIN
  RETURN QUERY
  SELECT
    n.id,
    n.title,
    n.blocks,
    n.created_at,
    nr.answers AS my_answers,
    (rd.user_id IS NOT NULL) AS read
  FROM public.notifications n
  LEFT JOIN public.notification_responses nr
    ON nr.notification_id = n.id AND nr.user_id = v_user
  LEFT JOIN public.notification_reads rd
    ON rd.notification_id = n.id AND rd.user_id = v_user
  LEFT JOIN public.notification_dismissals dm
    ON dm.notification_id = n.id AND dm.user_id = v_user
  WHERE n.published AND dm.notification_id IS NULL
  ORDER BY n.created_at DESC;
END $$;

GRANT EXECUTE ON FUNCTION public.list_notifications() TO anon, authenticated;
