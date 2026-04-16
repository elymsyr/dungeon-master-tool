-- ============================================================================
-- DMT — Batch fetch conversations RPC
-- ============================================================================
-- Replaces the N+1 client-side pattern in fetchMyConversations() with a
-- single RPC call that returns conversations + members + last message +
-- unread counts in one round-trip.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_my_conversations()
RETURNS JSON
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  RETURN COALESCE((
    SELECT json_agg(row_to_json(t) ORDER BY t.sort_ts DESC)
    FROM (
      SELECT
        c.id,
        c.is_group,
        c.title,
        c.created_by,
        c.created_at,
        -- Members with usernames
        (
          SELECT json_agg(json_build_object(
            'user_id', cm2.user_id,
            'username', p.username
          ))
          FROM conversation_members cm2
          JOIN profiles p ON p.user_id = cm2.user_id
          WHERE cm2.conversation_id = c.id
        ) AS members,
        -- Last message
        (
          SELECT json_build_object(
            'body', m.body,
            'created_at', m.created_at
          )
          FROM messages m
          WHERE m.conversation_id = c.id
          ORDER BY m.created_at DESC
          LIMIT 1
        ) AS last_message,
        -- Unread count
        (
          SELECT COUNT(m.id)
          FROM messages m
          WHERE m.conversation_id = c.id
            AND m.created_at > cm.last_read_at
            AND m.author_id <> v_uid
        ) AS unread_count,
        -- Sort key: latest message or conversation creation
        COALESCE(
          (SELECT MAX(m2.created_at) FROM messages m2 WHERE m2.conversation_id = c.id),
          c.created_at
        ) AS sort_ts
      FROM conversation_members cm
      JOIN conversations c ON c.id = cm.conversation_id
      WHERE cm.user_id = v_uid
    ) t
  ), '[]'::json);
END $$;

GRANT EXECUTE ON FUNCTION public.get_my_conversations() TO authenticated;

-- ── PostgREST schema cache reload ───────────────────────────────────────────
NOTIFY pgrst, 'reload schema';
