import 'builtin/builtin_dnd5e_v2_schema.dart';
import 'world_schema.dart';

/// Otomatik mekaniklerin tek kapısı.
///
/// Grant çözümleme ([CharacterResolver]), karakter yaratma sihirbazı, SRD
/// core bootstrap, spell slot / kaynak havuzu türetme — hepsi built-in
/// slug'larına (`class`, `species`, `player`, …) ve `grantFieldKeys` kapalı
/// sözleşmesine bağlı. Bu yüzden **yalnızca uygulamayla gelen built-in
/// template'te** çalışırlar.
///
/// Kullanıcı template'leri — built-in'in birebir kopyası bile olsa — saf
/// şema-güdümlü veridir: alanlar render edilir, değerler elle girilir,
/// hiçbir şey kendiliğinden hesaplanmaz. Kopyanın da mekaniksiz olması
/// bilinçli: kopya düzenlendiği anda resolver sessizce yanlış sonuç üretir,
/// "ne zaman bozulduğu" belirsiz bir kural olmaktansa net bir çizgi yeğdir.
bool templateIdHasMechanics(String? templateId) =>
    templateId == builtinDnd5eV2SchemaId;

bool schemaHasMechanics(WorldSchema? schema) =>
    templateIdHasMechanics(schema?.schemaId);
