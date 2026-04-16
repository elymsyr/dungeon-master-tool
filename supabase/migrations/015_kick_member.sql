-- ============================================================================
-- DMT — Kick member from group conversation
-- ============================================================================
-- Admin (created_by) can remove another member from a group conversation.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.kick_conversation_member(p_conv_id UUID, p_target_user UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  -- Cannot kick yourself — use leave_conversation instead.
  IF p_target_user = v_uid THEN
    RAISE EXCEPTION 'cannot kick yourself';
  END IF;

  -- Only admin of a group conversation can kick.
  IF NOT EXISTS (
    SELECT 1 FROM conversations
    WHERE id = p_conv_id AND created_by = v_uid AND is_group = true
  ) THEN
    RAISE EXCEPTION 'only group admin can kick members';
  END IF;

  -- Target must be a member.
  IF NOT EXISTS (
    SELECT 1 FROM conversation_members
    WHERE conversation_id = p_conv_id AND user_id = p_target_user
  ) THEN
    RAISE EXCEPTION 'user is not a member';
  END IF;

  DELETE FROM conversation_members
    WHERE conversation_id = p_conv_id AND user_id = p_target_user;
END $$;

GRANT EXECUTE ON FUNCTION public.kick_conversation_member(UUID, UUID) TO authenticated;

NOTIFY pgrst, 'reload schema';
