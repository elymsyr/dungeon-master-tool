import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_paths.dart';
import '../../core/config/supabase_config.dart';
import '../providers/user_session_provider.dart';
import '../providers/auth_provider.dart';

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
  await client.rpc('delete_my_account');
  return uid;
}

/// Oturumu kapatır ve silinen hesabın yerel ağacını (`users/{uid}`) siler.
/// Hata yutulur — hesap bulutta zaten yok, dosyaları kimse okumaz.
Future<void> finishAccountDeletion(WidgetRef ref, String uid) async {
  // DB'yi önce kapat: provider misafir köküne dönerken eski dosya kolunu
  // bırakır, ancak ondan sonra dizin silinebilir (Windows kilitli dosyayı
  // sildirmez). signOut'un hub listener'ı deactivate'i tekrar çağırırsa
  // zararsız — idempotent.
  await ref.read(userSessionProvider.notifier).deactivate();
  await ref.read(authProvider.notifier).signOut();

  try {
    final dir = Directory(p.join(AppPaths.dataRoot, 'users', uid));
    if (await dir.exists()) await dir.delete(recursive: true);
  } catch (e) {
    debugPrint('Local user tree delete failed: $e');
  }
}

/// Bucket başına `{uid}/` klasörünü listeleyip siler.
// ponytail: klasör tek seviye taranır — bugün tüm yükleyiciler `{uid}/{sha}.{ext}`
// yazıyor. İç içe path'li bir bucket eklenirse burası recursive olmalı.
Future<void> _purgeStorage(SupabaseClient client, String uid) async {
  for (final bucket in _ownedBuckets) {
    final files = await client.storage.from(bucket).list(path: uid);
    if (files.isEmpty) continue;
    await client.storage
        .from(bucket)
        .remove([for (final f in files) '$uid/${f.name}']);
  }
}

/// Worker `/admin/purge-user` — kullanıcı kendi JWT'siyle kendi prefix'ini
/// sildirir. Worker URL'i derlenmemişse (offline build) R2 zaten kullanılmıyor.
Future<void> _purgeR2(String uid, String token) async {
  if (_workerBaseUrl.isEmpty) return;
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
