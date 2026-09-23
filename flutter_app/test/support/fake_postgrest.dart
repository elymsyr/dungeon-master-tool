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

  /// Aynı istekler ayrıntısıyla — sorgu, gövde ve içerik başlıkları.
  final List<FakeCall> calls = [];

  /// Sunucunun kökü — imzalı URL gibi başka uçları da buraya yönlendirmek için.
  String get baseUrl => 'http://127.0.0.1:${_server.port}';

  static Future<FakePostgrest> start({required String uid}) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final client = SupabaseClient('http://127.0.0.1:${server.port}', 'test-key');
    final fake = FakePostgrest._(server, client);
    server.listen((req) async {
      final sent = await const Utf8Decoder(allowMalformed: true).bind(req).join();
      fake.requests.add('${req.method} ${req.uri.path}');
      fake.calls.add(FakeCall(req.method, req.uri, sent,
          contentType: req.headers.value(HttpHeaders.contentTypeHeader),
          contentLength: req.headers.contentLength));
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

class FakeCall {
  const FakeCall(this.method, this.uri, this.body,
      {this.contentType, this.contentLength = -1});
  final String method;
  final Uri uri;
  final String body;
  final String? contentType;
  final int contentLength;

  Object? get json => jsonDecode(body);
}
