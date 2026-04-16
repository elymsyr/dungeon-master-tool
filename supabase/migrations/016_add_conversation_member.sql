-- ============================================================================
-- DMT — Add member to group conversation
-- ============================================================================
-- Admin (created_by) can add a new member to a group conversation.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.add_conversation_member(p_conv_id UUID, p_target_user UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  -- Only admin of a group conversation can add members.
  IF NOT EXISTS (
    SELECT 1 FROM conversations
    WHERE id = p_conv_id AND created_by = v_uid AND is_group = true
  ) THEN
    RAISE EXCEPTION 'only group admin can add members';
  END IF;

  -- Target must not already be a member.
  IF EXISTS (
    SELECT 1 FROM conversation_members
    WHERE conversation_id = p_conv_id AND user_id = p_target_user
  ) THEN
    RAISE EXCEPTION 'user is already a member';
  END IF;

  INSERT INTO conversation_members (conversation_id, user_id)
  VALUES (p_conv_id, p_target_user);
END $$;

GRANT EXECUTE ON FUNCTION public.add_conversation_member(UUID, UUID) TO authenticated;

NOTIFY pgrst, 'reload schema';
