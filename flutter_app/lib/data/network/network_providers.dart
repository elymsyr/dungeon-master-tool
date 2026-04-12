import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_paths.dart';
import '../../core/config/supabase_config.dart';
import 'asset_service.dart';
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

  final cacheDir = Directory(p.join(AppPaths.cacheDir, 'r2'));
  final service = AssetService(
    supabase: Supabase.instance.client,
    workerBaseUrl: _workerBaseUrl,
    cacheDir: cacheDir,
  );
  return service;
});
