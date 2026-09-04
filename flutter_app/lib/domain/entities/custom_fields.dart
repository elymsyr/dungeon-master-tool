import 'dart:convert';

import 'schema/field_schema.dart';

/// Serbest alanlar ("free fields") — tek bir karta ait, şemada olmayan alan
/// tanımları.
///
/// Neden kartın kendi `fields` map'inde: entity attributes zaten tipsiz bir
/// map ve olduğu gibi `fields_json`'a yazılıyor. Tanımı da oraya koyunca
/// kaydetme, LAN sync ve share broadcast (`payload_json`) yollarının hiçbiri
/// değişmiyor — alan kartla birlikte gider, kart bir dünyada da olsa bir
/// pakette de.
///
/// **Template'e asla dokunmaz.** Built-in ya da custom, kaynak şema olduğu
/// gibi kalır; alan yalnızca bu kartta görünür. Aynı sebeple serbest alanlar
/// **her zaman saf veridir** — grant sözleşmesi (`grantFieldKeys`) kapalı bir
/// kümedir, buraya eklenen bir anahtar hiçbir mekaniği tetiklemez.
const kCustomFieldsKey = '_custom_fields';

/// [entityFields] içindeki serbest alan tanımları. Bozuk kayıtlar atlanır.
List<FieldSchema> customFieldsOf(Map<String, dynamic> entityFields) {
  final raw = entityFields[kCustomFieldsKey];
  if (raw is! List) return const [];
  final out = <FieldSchema>[];
  for (final e in raw) {
    if (e is! Map) continue;
    try {
      out.add(FieldSchema.fromJson(Map<String, dynamic>.from(e)));
    } catch (_) {
      // Tek bozuk tanım kartın tamamını düşürmesin.
    }
  }
  return out;
}

/// Düz JSON'a indirger. `FieldSchema.toJson()` iç içe freezed nesnelerini
/// (ör. `validation`) olduğu gibi bırakıyor; kart map'i diske yazılmadan önce
/// de okunduğu için burada bir kez normalize ediyoruz — yoksa alan kaydedilip
/// yeniden yüklenene kadar görünmez oluyor.
List<Map<String, dynamic>> encodeCustomFields(List<FieldSchema> fields) =>
    (jsonDecode(jsonEncode([for (final f in fields) f.toJson()])) as List)
        .cast<Map<String, dynamic>>();
