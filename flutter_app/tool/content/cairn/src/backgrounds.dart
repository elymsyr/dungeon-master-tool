/// `second-edition/backgrounds/*.md` (20 dosya) → `background`.
///
/// Gövde birebir `description`'a gider: alıntı, Names satırı, Starting Gear
/// listesi ve iki d6 tablosu. Tablolar gerçek mekanik taşıyor (büyü kitabı,
/// +1 Armor, stat blokları) — özetlenemez, ayrıştırılıp alanlara da
/// dağıtılamaz; şemada karşılığı yok.
///
/// `starting_gold_gp` **yazılmaz**: kaynak "3d6 Gold Pieces" diyor, alan
/// tamsayı — ortalama yazmak sayı uydurmak olurdu. Metin description'da.
/// `granted_skill_refs` / ASI / feat de yok — Cairn'de böyle bir kavram yok.
///
/// `default_inventory_refs` de **yazılmıyor** (plan §2'de taşıyıcı alan olarak
/// listeli). Alan yalnız `adventuring-gear|ammunition|armor|pack|tool|weapon`
/// hedefi kabul ediyor; Starting Gear maddeleri ise eşya *adı değil*, adı +
/// satır içi mekaniği ("Leech (restores 1 STR, 3 uses)"), bir tanesi iki
/// satıra sarılmış tam bir büyü metni (half-witch), bir tanesi `vehicle`
/// (mountebank'in Cart'ı — alanın kabul etmediği kategori), bir tanesi de
/// hedefi olmayan bir tablo göndermesi ("Bow (see table)", fletchwind).
/// Bunları ref'e çevirmek ~110 yeni eşya kartı basmak, yarısını marketplace
/// satırlarının farklı yazımıyla ikizlemek ("Crossbow (d8, _bulky_)" vs
/// "Crossbow (d8 damage, _bulky_)") ve adı mekanikten ayırmak için kaynağın
/// vermediği bir sezgi yazmak demek. Liste zaten `description`'da birebir
/// duruyor; kayıp yok. Faz 7'de Cairn dünyaları gelip oyuncu gerçekten Cairn
/// karakteri yarattığında ref'lenir.
library;

import '../bp.dart';

Map<String, List<Bp>> parseBackgrounds(String cairn) => {
      'background': [
        for (final path in mdFiles('$cairn/second-edition/backgrounds'))
          _background(readMd(path)),
      ],
    };

/// Ad `# Başlık` satırından; başlık gövdede de kalır (birebirlik).
Bp _background(String md) {
  final body = md.trim();
  final h1 = RegExp(r'^#[^#].*$', multiLine: true).firstMatch(body);
  if (h1 == null) throw StateError('background başlığı yok:\n${body.split('\n').first}');
  return bpEntity(plain(h1.group(0)!.substring(1)), {'description': body});
}
