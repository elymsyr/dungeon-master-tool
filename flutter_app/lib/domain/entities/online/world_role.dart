/// Kullanıcının aktif worlddeki rolü. Online (paylaşılan) worldlerde:
///   - [dm]    : DM (yönetici) — full read/write.
///   - [player]: davetli oyuncu — kısıtlı görünürlük + kendi karakteri.
///   - [none]  : world online değil veya kullanıcı üye değil. Lokal-only
///     worldler için varsayılan; tüm UI DM modunda render edilir.
enum WorldRole { dm, player, none }

extension WorldRoleX on WorldRole {
  bool get isDm => this == WorldRole.dm;
  bool get isPlayer => this == WorldRole.player;
  bool get isOnline => this != WorldRole.none;
}
