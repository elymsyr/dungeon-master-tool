-- Posts can optionally reference a game listing.
ALTER TABLE public.posts
  ADD COLUMN game_listing_id UUID
  REFERENCES public.game_listings(id) ON DELETE SET NULL;

CREATE INDEX idx_posts_game_listing ON public.posts (game_listing_id)
  WHERE game_listing_id IS NOT NULL;
