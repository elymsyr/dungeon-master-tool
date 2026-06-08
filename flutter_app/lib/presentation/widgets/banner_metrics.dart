/// Shared banner cover geometry for world/package/template/marketplace cards.
/// Single source of truth so every top-banner surface renders identically on
/// mobile and desktop. Source banners are cropped to 2:1; cover-fit at this
/// fixed height preserves aspect (edge-crop only, no stretch). Source banners
/// are cropped to 3:2 (see tool/optimize_banners.py).
const double kBannerCoverHeight = 220;
const int kBannerCoverCacheHeight = 440; // ~2x DPR decode
