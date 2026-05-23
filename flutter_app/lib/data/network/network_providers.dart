import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../application/services/content_store.dart';
import '../../core/config/supabase_config.dart';
import 'asset_service.dart';
import 'free_media_service.dart';
import 'network_bridge.dart';
import 'no_op_network_bridge.dart';
import 'no_op_session_manager.dart';
import 'session_manager.dart';

/// NetworkBridge provider — default: NoOp (offline).
/// Online'a geçildiğinde override ile SupabaseNetworkBridge enjekte edilir.
final networkBridgeProvider = Provider<NetworkBridge>((ref) {
  final bridge = NoOpNetworkBridge();
  ref.onDispose(bridge.dispose);
  return bridge;
});

/// SessionManager provider — default: NoOp (offline).
final sessionManagerProvider = Provider<SessionManager>((ref) {
  final manager = NoOpSessionManager();
  ref.onDispose(manager.dispose);
  return manager;
});

/// Cloudflare Worker base URL — `--dart-define=DMT_WORKER_URL=...`.
/// Boş ise AssetService null döner (offline fallback).
const String _workerBaseUrl = String.fromEnvironment('DMT_WORKER_URL');

/// AssetService — Cloudflare R2 asset pipeline (docs/ONLINE_REPORT.md §4.3).
///
/// Supabase konfigüre değilse veya `DMT_WORKER_URL` boşsa null döner;
/// bu durumda çağıranlar offline fallback yapmalı.
final assetServiceProvider = Provider<AssetService?>((ref) {
  if (!SupabaseConfig.isConfigured || _workerBaseUrl.isEmpty) return null;
  // Runtime guard: sub-isolates (player sub-window) may compile with the
  // flags set but fail/skip Supabase.initialize(). Reading
  // Supabase.instance.client there throws an assertion. Return null →
  // callers fall back to local resolution.
  final SupabaseClient client;
  try {
    client = Supabase.instance.client;
  } catch (_) {
    return null;
  }
  final service = AssetService(
    supabase: client,
    workerBaseUrl: _workerBaseUrl,
    contentStore: ref.watch(contentStoreProvider),
  );
  return service;
});

/// FreeMediaService — ücretsiz medya pipeline (Supabase Storage `free-media`).
///
/// Karakter portresi + world/package kapak resimleri buradan gider; quota'ya
/// sayılmaz. Worker URL gerekmez — yalnızca Supabase konfigüre olmalı.
/// Konfigüre değilse null döner; çağıranlar local fallback yapar.
final freeMediaServiceProvider = Provider<FreeMediaService?>((ref) {
  if (!SupabaseConfig.isConfigured) return null;
  final SupabaseClient client;
  try {
    client = Supabase.instance.client;
  } catch (_) {
    return null;
  }
  return FreeMediaService(
    supabase: client,
    contentStore: ref.watch(contentStoreProvider),
  );
});
