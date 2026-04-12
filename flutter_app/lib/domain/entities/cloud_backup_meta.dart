import 'package:freezed_annotation/freezed_annotation.dart';

part 'cloud_backup_meta.freezed.dart';
part 'cloud_backup_meta.g.dart';

/// Supabase'deki bir cloud backup kaydinin metadata'si.
/// Gercek veri Supabase Storage'da gzip JSON olarak saklanir;
/// bu model yalnizca `cloud_backups` Postgres tablosundaki lightweight satirdir.
///
/// [type] degerleri: `world`, `template`, `package`.
/// [itemName] genel amaçlı isim alanıdır (kampanya adı, template adı, paket adı).
@freezed
abstract class CloudBackupMeta with _$CloudBackupMeta {
  const factory CloudBackupMeta({
    required String id,
    required String userId,
    /// Genel item adı (world name, template name veya package name).
    required String itemName,
    /// Item'ın unique ID'si (world_id, schemaId, package_id).
    required String itemId,
    /// `world`, `template`, `package`
    @Default('world') String type,
    required String storagePath,
    required int sizeBytes,
    @Default(0) int entityCount,
    @Default(5) int schemaVersion,
    String? appVersion,
    required DateTime createdAt,
    String? notes,
  }) = _CloudBackupMeta;

  factory CloudBackupMeta.fromJson(Map<String, dynamic> json) =>
      _$CloudBackupMetaFromJson(json);
}
