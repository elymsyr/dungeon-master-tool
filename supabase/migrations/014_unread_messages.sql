-- ============================================================================
-- DMT — Unread message tracking
-- ============================================================================
-- Adds last_read_at to conversation_members and RPCs for unread counts.
-- ============================================================================

-- ── 1. Add last_read_at column ───────────────────────────────────────────────
ALTER TABLE public.conversation_members
  ADD COLUMN last_read_at TIMESTAMPTZ NOT NULL DEFAULT now();

-- ── 2. mark_conversation_read ────────────────────────────────────────────────
-- Sets last_read_at = now() for the calling user in a specific conversation.

CREATE OR REPLACE FUNCTION public.mark_conversation_read(p_conv_id UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE public.conversation_members
     SET last_read_at = now()
   WHERE conversation_id = p_conv_id
     AND user_id = auth.uid();
END $$;

GRANT EXECUTE ON FUNCTION public.mark_conversation_read(UUID) TO authenticated;

-- ── 3. get_unread_counts ─────────────────────────────────────────────────────
-- Returns per-conversation unread message counts for the calling user.

CREATE OR REPLACE FUNCTION public.get_unread_counts()
RETURNS TABLE(conversation_id UUID, unread_count BIGINT)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT
    cm.conversation_id,
    COUNT(m.id) AS unread_count
  FROM public.conversation_members cm
  LEFT JOIN public.messages m
    ON m.conversation_id = cm.conversation_id
    AND m.created_at > cm.last_read_at
    AND m.author_id <> auth.uid()
  WHERE cm.user_id = auth.uid()
  GROUP BY cm.conversation_id;
$$;

GRANT EXECUTE ON FUNCTION public.get_unread_counts() TO authenticated;

-- ── 4. get_total_unread_count ────────────────────────────────────────────────
-- Returns the total unread message count across all conversations (for badge).

CREATE OR REPLACE FUNCTION public.get_total_unread_count()
RETURNS BIGINT
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT COALESCE(SUM(cnt), 0)::BIGINT
  FROM (
    SELECT COUNT(m.id) AS cnt
    FROM public.conversation_members cm
    JOIN public.messages m
      ON m.conversation_id = cm.conversation_id
      AND m.created_at > cm.last_read_at
      AND m.author_id <> auth.uid()
    WHERE cm.user_id = auth.uid()
    GROUP BY cm.conversation_id
  ) sub;
$$;

GRANT EXECUTE ON FUNCTION public.get_total_unread_count() TO authenticated;

-- ── 5. PostgREST schema cache reload ─────────────────────────────────────────
NOTIFY pgrst, 'reload schema';
