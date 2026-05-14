-- ============================================================================
-- 027_fix_rls_bypass.sql — DMT Online Multiplayer hotfix
-- ============================================================================
-- Problem: PR-O1 (026) SECURITY DEFINER trigger `tg_world_insert_dm_member`
-- ve RPC fonksiyonları INSERT yaparken world_members tablosuna düşen
-- satırların RLS politikası ile çakıştığı bir senaryo gözlemlendi
-- ("new row violates row-level security policy for table world_members").
--
-- Sebep: SECURITY DEFINER fonksiyonu, definer rolünün RLS bypass yetkisine
-- bağlıdır. Supabase'de bu davranış güvenilir değildir; en sağlam yol
-- fonksiyona açıkça `SET row_security = off` koymak. Bu migration tüm
-- ilgili fonksiyonlara bu config'i ekler ve ek bir self-insert policy
-- yedek olarak bırakır.
-- ============================================================================

-- ── BÖLÜM A — SECURITY DEFINER fonksiyonlarda RLS'i kapat ─────────────────

ALTER FUNCTION public.tg_world_insert_dm_member()
  SET row_security = off;

ALTER FUNCTION public.create_world_invite(TEXT, INT, INT)
  SET row_security = off;

ALTER FUNCTION public.redeem_world_invite(TEXT)
  SET row_security = off;

ALTER FUNCTION public.claim_character(TEXT)
  SET row_security = off;

-- is_world_member / is_world_dm / can_access_map zaten SELECT'tir, RLS off
-- gerek yok ama SECURITY DEFINER'lar olarak da güvende olmaları için aynı.
ALTER FUNCTION public.is_world_member(TEXT) SET row_security = off;
ALTER FUNCTION public.is_world_dm(TEXT)     SET row_security = off;
ALTER FUNCTION public.can_access_map(TEXT, TEXT) SET row_security = off;

-- ── BÖLÜM B — Yedek INSERT policy'leri ──────────────────────────────────
-- Eğer (üstü mantıken kapatsa da) bypass yine de gerçekleşmezse,
-- aşağıdaki policy'ler self-DM ve self-player INSERT'lerini izin verir.
-- Trigger NEW.user_id = NEW.owner_id (auth.uid()) garantili olduğundan
-- güvenli.

DROP POLICY IF EXISTS "Members: self dm insert" ON public.world_members;
CREATE POLICY "Members: self dm insert"
  ON public.world_members FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND role = 'dm'
    AND EXISTS (
      SELECT 1 FROM public.worlds w
      WHERE w.id = world_members.world_id AND w.owner_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Members: self player insert" ON public.world_members;
CREATE POLICY "Members: self player insert"
  ON public.world_members FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND role = 'player'
  );

-- ── BÖLÜM C — PostgREST schema cache reload ─────────────────────────────
NOTIFY pgrst, 'reload schema';
