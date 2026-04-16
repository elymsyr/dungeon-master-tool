-- Posts can optionally reference a marketplace listing.
ALTER TABLE public.posts
  ADD COLUMN marketplace_item_id UUID
  REFERENCES public.marketplace_listings(id) ON DELETE SET NULL;

CREATE INDEX idx_posts_marketplace ON public.posts (marketplace_item_id)
  WHERE marketplace_item_id IS NOT NULL;
