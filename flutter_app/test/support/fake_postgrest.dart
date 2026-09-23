import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Ağsız sahte PostgREST: `dart:io` ile yerel bir sunucu, istekleri geldiği
/// sırayla [replies]'tan yanıtlar. Servislerin RPC / select / update yolları
/// gerçekten koşar; yalnız karşı taraf sahte.
///
/// Oturum: erişim jetonu JWT değil → gotrue süresini bilmiyor, ağa çıkmadan
/// kabul ediyor ([uid] ile `currentUser` dolu).
class FakePostgrest {
  FakePostgrest._(this._server, this.client);

  final HttpServer _server;
  final SupabaseClient client;

  /// Sıradaki isteğin yanıtı: (durum, gövde). İstek geldiği anda çağrılır.
  final List<FutureOr<(int, Object)> Function()> replies = [];

  /// Gelen istekler, `"METHOD /yol"` biçiminde.
  final List<String> requests = [];

  static Future<FakePostgrest> start({required String uid}) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final client = SupabaseClient('http://127.0.0.1:${server.port}', 'test-key');
    final fake = FakePostgrest._(server, client);
    server.listen((req) async {
      await utf8.decoder.bind(req).join();
      fake.requests.add('${req.method} ${req.uri.path}');
      final (status, body) = fake.replies.isEmpty
          ? (500, {'message': 'beklenmeyen istek: ${req.method} ${req.uri}'})
          : await fake.replies.removeAt(0)();
      req.response
        ..statusCode = status
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(body));
      await req.response.close();
    });
    await client.auth.recoverSession(jsonEncode({
      'access_token': 'test-token',
      'token_type': 'bearer',
      'user': {'id': uid, 'aud': 'authenticated', 'created_at': ''},
    }));
    return fake;
  }

  Future<void> close() async {
    await client.dispose();
    await _server.close(force: true);
  }
}
