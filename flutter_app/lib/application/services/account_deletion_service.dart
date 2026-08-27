import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_paths.dart';
import '../../core/config/supabase_config.dart';
import '../../data/database/database_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/user_session_provider.dart';
import 'guest_promotion_service.dart';

/// Cloudflare Worker base URL — network_providers.dart ile aynı define.
const String _workerBaseUrl = String.fromEnvironment('DMT_WORKER_URL');

/// Kullanıcının sahibi olduğu objelerin yattığı Supabase Storage bucket'ları.
/// Hepsinde path şeması `{uid}/{dosya}` ve owner-delete RLS policy'si var
/// (bkz. 004_likes_and_storage.sql, 053_free_media_bucket.sql).
const _ownedBuckets = ['avatars', 'post-images', 'shared-payloads', 'free-media'];

/// Hesabın **bulut** tarafını siler: storage objeleri, R2 objeleri ve
/// `auth.users` satırı (public şemadaki her şey FK cascade ile peşinden gider).
///
/// Sıra önemli — hesap satırı gittikten sonra kullanıcının JWT'si ile
/// yapılabilecek hiçbir temizlik kalmaz, o yüzden objeler önce gider.
/// Hatalar yukarı fırlar: hiçbiri kısmi silme bırakmaz (obje silme idempotent,
/// RPC ya hep ya hiç), kullanıcı tekrar dener.
///
/// Yerel tarafı [finishAccountDeletion] tamamlar. İkisi bilerek ayrı: oturum
/// kapatma ekranı landing'e taşıyor, o yüzden çağıran taraf ilerleme dialog'unu
/// **arada** kapatabilsin diye (dispose olan bir Navigator'da `pop`
/// `!_debugLocked` assert'ini attırıyor).
Future<String> deleteCloudAccountData(WidgetRef ref) async {
  if (!SupabaseConfig.isConfigured) {
    throw StateError('Supabase not configured');
  }
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  final token = client.auth.currentSession?.accessToken;
  if (user == null || token == null) {
    throw StateError('Not signed in');
  }
  final uid = user.id;

  await _purgeStorage(client, uid);
  await _purgeR2(uid, token);
  // Dönüş değeri kontrol edilir: RPC `auth.uid()` NULL ise sessizce FALSE
  // döner — bunu yutmak, hiçbir şey silinmemişken hesabı silinmiş sanmaktır.
  final deleted = await client.rpc('delete_my_account');
  if (deleted != true) {
    throw StateError('delete_my_account returned $deleted');
  }
  return uid;
}

/// Yerel ağacı misafir köküne geri verir ve oturumu kapatır.
///
/// **Yerel veri silinmez.** Hesabın bulut tarafı gitti, ama diskteki dünyalar
/// / karakterler / paketler kullanıcının kendi makinesinde: hesabını silen biri
/// aynı cihazda misafir olarak girip kaldığı yerden devam edebilmeli. Devir
/// (`GuestPromotionService.copyIntoAccount`) ne yaptıysa
/// [GuestPromotionService.demoteAccountToGuest] onu geri alır.
///
/// Hata yutulur: taşıma başarısızsa ağaç `users/{uid}` altında olduğu gibi
/// kalır — kullanıcı ona ulaşamaz ama hiçbir şey kaybolmaz.
Future<void> finishAccountDeletion(WidgetRef ref, String uid) async {
  final guest = GuestPromotionService(dataRoot: AppPaths.dataRoot);
  try {
    // Karakterlerin sahipliği DB kapanmadan düşer: hub'ın karakter sekmesi
    // own-only, silinmiş bir uid'e ait satır misafirde hiçbir ekranda
    // görünmez (bkz. releaseAccountCharacters).
    final released =
        await guest.releaseAccountCharacters(ref.read(appDatabaseProvider), uid);
    debugPrint('Characters released to guest ownership: $released');
    // Gövdelerdeki mutlak medya yolları hâlâ `users/{uid}/...` gösteriyor;
    // demote dosyaları taşıyor, bu da kayıtları peşinden çeviriyor.
    final paths =
        await guest.restoreGuestPaths(ref.read(appDatabaseProvider), uid);
    debugPrint('Media paths pointed back at the guest root: $paths');
  } catch (e) {
    debugPrint('Character release / path restore failed: $e');
  }

  try {
    // Taşımadan önce DB kapanmalı (WAL çifti de taşınıyor). `deactivate()`
    // misafir köküne dönerken yeni DB'yi açtığı için taşıma ondan **önce**
    // bitmeli — aksi halde açılan boş dosya taşınacak olanın yerini alır.
    await ref.read(appDatabaseProvider).close();
    final report = await guest.demoteAccountToGuest(uid);
    debugPrint('Account tree handed back to guest: $report');
  } catch (e, st) {
    debugPrint('Account tree handback failed: $e\n$st');
  }

  await ref.read(userSessionProvider.notifier).deactivate();
  await ref.read(authProvider.notifier).signOut();
}

/// Kullanıcının `{uid}/` prefix'i altındaki her objeyi siler.
///
/// Klasör klasör iner: `shared-payloads` içinde marketplace payload'ları
/// `{uid}/listings/{id}.json.gz` yolunda duruyor, tek seviye tarayan ilk hâli
/// bunları hiç görmüyordu (`list` klasörü `id == null` olan bir girdi olarak
/// döndürüyor, `remove` ona dokunmuyordu).
Future<void> _purgeStorage(SupabaseClient client, String uid) async {
  for (final bucket in _ownedBuckets) {
    try {
      await _purgeStorageFolder(client, bucket, uid);
    } on StateError catch (e) {
      throw StateError('$bucket → ${e.message}');
    }
  }
}

/// Bir sayfada dönen azami obje sayısı. `SearchOptions.limit` varsayılanı
/// **100**'dür (storage_client `types.dart`) ve `list()` onu gövdeye koyar —
/// belirtmezsek 100'den fazlası hiç listelenmez, dolayısıyla hiç silinmez ve
/// hata da alınmaz. Hesabı silinmiş kullanıcının artık RLS'i eşleşmediği için
/// o objeler kalıcı olarak erişilemez hâle gelirdi.
const _storagePageSize = 1000;

/// Bir turda silinemeyecek kadar dolu klasör için üst sınır: 200 × 1000 obje.
/// Aşılırsa döngü değil hata — sessiz eksik silme bir daha olmasın.
const _storageMaxPasses = 200;

/// [purgeStorageTree]'nin gördüğü tek girdi şekli. Supabase `list` bir klasörü
/// `id == null` olan bir girdi olarak döndürür.
typedef StorageEntry = ({String name, bool isFolder});

/// Silme döngüsünün Supabase'den ayrılmış hâli — IO iki closure'a taşındığı
/// için testten düz fonksiyonlarla sürülebiliyor. [remove] gerçekten silinen
/// obje **sayısını** döndürmeli.
@visibleForTesting
Future<void> purgeStorageTree({
  required Future<List<StorageEntry>> Function(String path) list,
  required Future<int> Function(List<String> keys) remove,
  required String path,
}) async {
  // Sildikçe offset kaydığı için sayfalama offset'le değil "her turda baştan
  // oku, dosya kalmayana kadar sil" ile yapılıyor. Klasörler sanal: altları
  // boşalınca listeden kendiliğinden düşerler.
  for (var pass = 0; pass < _storageMaxPasses; pass++) {
    final entries = await list(path);
    final files = <String>[];
    final folders = <String>[];
    for (final entry in entries) {
      (entry.isFolder ? folders : files).add(entry.name);
    }
    // Klasör klasör iner: `shared-payloads` içinde marketplace payload'ları
    // `{uid}/listings/{id}.json.gz` yolunda duruyor.
    for (final folder in folders) {
      await purgeStorageTree(list: list, remove: remove, path: '$path/$folder');
    }
    if (files.isEmpty) return;

    final keys = [for (final file in files) '$path/$file'];
    final removed = await remove(keys);
    if (removed != keys.length) {
      throw StateError(
        'storage purge incomplete: $path ($removed/${keys.length} silindi)',
      );
    }
  }
  throw StateError('storage purge did not converge: $path');
}

Future<void> _purgeStorageFolder(
  SupabaseClient client,
  String bucket,
  String path,
) =>
    purgeStorageTree(
      path: path,
      list: (p) async {
        final entries = await client.storage.from(bucket).list(
              path: p,
              searchOptions: const SearchOptions(limit: _storagePageSize),
            );
        return [
          for (final e in entries) (name: e.name, isFolder: e.id == null),
        ];
      },
      // `remove` yalnız GERÇEKTEN sildiklerini döner; RLS bir objeyi engellerse
      // 200 + eksik liste gelir, exception gelmez. Farkı çağıran yakalıyor.
      remove: (keys) async =>
          (await client.storage.from(bucket).remove(keys)).length,
    );

/// Worker `/admin/purge-user` — kullanıcı kendi JWT'siyle kendi prefix'ini
/// sildirir.
///
/// Boş worker URL'i "R2 kullanılmıyor" demek **değil**: buraya gelindiğinde
/// `SupabaseConfig.isConfigured` zaten true, yani bu online bir build ve tek
/// eksik `DMT_WORKER_URL` define'ı. Aynı hesap daha önce worker URL'li bir
/// build'den (CI release) obje yüklemiş olabilir; sessizce atlarsak
/// `delete_my_account()` çalıştıktan sonra o objeler **kalıcı olarak** yetim
/// kalır — `/admin/purge-user`'ın kullanıcı yolu `sub == user_id` istiyor ve o
/// `sub` için artık token üretilemez. O yüzden sessiz `return` değil, hata.
Future<void> _purgeR2(String uid, String token) async {
  if (_workerBaseUrl.isEmpty) {
    throw StateError(
      'DMT_WORKER_URL not compiled in; R2 objects would be orphaned',
    );
  }
  final base = _workerBaseUrl.replaceAll(RegExp(r'/$'), '');
  final httpClient = HttpClient();
  try {
    final req = await httpClient.postUrl(Uri.parse('$base/admin/purge-user'));
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode({'user_id': uid}));
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode != 200) {
      throw HttpException('purge-user failed (${res.statusCode}): $body');
    }
  } finally {
    httpClient.close();
  }
}
