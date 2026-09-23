// Faz 5d — bulutta henüz olmayan görsel (DM'in cihazı yüklemeyi bitirmedi)
// kırık ikonda kalmaz: widget artan aralıklarla yeniden çözer, görsel gelince
// yerine geçer.
//
//   flutter test test/presentation/widgets/asset_ref_image_retry_test.dart

import 'dart:io';

import 'package:dungeon_master_tool/application/services/asset_ref_resolver.dart';
import 'package:dungeon_master_tool/domain/value_objects/asset_ref.dart';
import 'package:dungeon_master_tool/presentation/widgets/asset_ref_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _LateResolver implements AssetRefResolver {
  File? next;
  int calls = 0;

  @override
  Future<File?> resolve(AssetRef ref) async {
    calls++;
    return next;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  Future<_LateResolver> pumpImage(WidgetTester tester, String ref) async {
    final r = _LateResolver();
    await tester.pumpWidget(ProviderScope(
      overrides: [assetRefResolverProvider.overrideWithValue(r)],
      child: MaterialApp(home: AssetRefImage(ref: AssetRef(ref))),
    ));
    await tester.pump();
    return r;
  }

  testWidgets('bulut görseli gelene kadar geri çekilerek yeniden denenir',
      (tester) async {
    final r = await pumpImage(tester, 'dmt-content://${'a' * 64}.png');
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    expect(r.calls, 1);

    await tester.pump(mediaRetryDelay(0));
    expect(r.calls, 2);
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget,
        reason: 'deneme sırasında spinner\'a dönülmez');

    r.next = File('gelen.png');
    await tester.pump(mediaRetryDelay(1));
    await tester.pump();
    expect(r.calls, 3);
    expect(find.byType(Image), findsOneWidget);

    await tester.pump(mediaRetryDelay(5));
    expect(r.calls, 3, reason: 'gelen görsel bir daha sorulmaz');
  });

  testWidgets('yerel yol yeniden denenmez', (tester) async {
    final r = await pumpImage(tester, '/yok/boyle/bir/dosya.png');
    await tester.pump(mediaRetryDelay(5));
    expect(r.calls, 1);
  });
}
