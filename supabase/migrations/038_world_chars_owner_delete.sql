-- ============================================================================
-- 038_world_chars_owner_delete.sql — owner can DELETE own world_characters row
-- ============================================================================
-- Player "Remove from world" (characters_sidebar offline path veya yeni
-- online path) DB satırını silebilsin diye RLS DELETE policy'si eklendi.
-- 026'da yalnızca DM full vardı; owner sadece SELECT/UPDATE/INSERT alıyordu.
-- DELETE'siz, player kendi karakterini world'den çıkardığında local
-- worldName temizleniyor ama DB mirror row kalıyor → diğer üyeler ve DM
-- hâlâ "bu world'de" olarak görüyor.
-- ============================================================================

DROP POLICY IF EXISTS "Chars: player deletes own" ON public.world_characters;
CREATE POLICY "Chars: player deletes own"
  ON public.world_characters FOR DELETE
  USING (public.is_world_member(world_id) AND owner_id = auth.uid());

NOTIFY pgrst, 'reload schema';
