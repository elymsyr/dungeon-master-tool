/// Shared banner cover geometry for world/package/template/marketplace cards.
/// Single source of truth so every top-banner surface renders identically on
/// mobile and desktop. Source banners are cropped to 2:1; cover-fit at this
/// Cards are capped to [kCardMaxWidth] everywhere; the banner is a fixed 2:1
/// AspectRatio box, so source banners (cropped to 2:1) display in full with no
/// edge-crop, identical on mobile and desktop.
const double kBannerCoverAspect = 2 / 1; // width / height
const int kBannerCoverCacheWidth = 1200; // ~2x of the capped card width
const double kCardMaxWidth = 500;
