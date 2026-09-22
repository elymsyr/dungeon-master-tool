import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dungeon_master_tool/presentation/widgets/compactable_button.dart';

Widget _host(Size size) => MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(
        home: Scaffold(
          body: CompactableButton(
            icon: const Icon(Icons.content_copy, size: 18),
            label: 'Kopyala',
            onPressed: () {},
          ),
        ),
      ),
    );

void main() {
  testWidgets('geniş ekranda etiket görünür', (tester) async {
    await tester.pumpWidget(_host(const Size(800, 600)));
    expect(find.text('Kopyala'), findsOneWidget);
  });

  testWidgets('dar ekranda yalnız simge kalır, etiket tooltip olur',
      (tester) async {
    await tester.pumpWidget(_host(const Size(360, 640)));
    expect(find.text('Kopyala'), findsNothing);
    expect(find.byIcon(Icons.content_copy), findsOneWidget);
    expect(
      tester.widget<Tooltip>(find.byType(Tooltip)).message,
      'Kopyala',
    );
    // Satırdaki komşularıyla aynı yükseklik — simge hâli alçalmamalı.
    final compactHeight = tester.getSize(find.byType(OutlinedButton)).height;
    await tester.pumpWidget(_host(const Size(800, 600)));
    expect(
      compactHeight,
      tester.getSize(find.byType(OutlinedButton)).height,
    );
  });
}
