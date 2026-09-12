import 'package:flutter_test/flutter_test.dart';
import 'package:dungeon_master_tool/application/providers/ui_state_provider.dart';

/// Dünya silinince görünüm izleri de gitmeli: mapler dünya **adıyla**
/// anahtarlı, temizlenmezse aynı adla inen bir sonraki dünya silinenin açık
/// kartlarını ve PDF sekmelerini miras alıyor.
void main() {
  const seed = UiState(
    dbOpenLeftByWorld: {
      'Aegis': ['e1'],
      'Baska': ['e9'],
    },
    dbOpenRightByWorld: {
      'Aegis': ['e2'],
    },
    dbActiveLeftByWorld: {'Aegis': 0, 'Baska': 1},
    dbActiveRightByWorld: {'Aegis': 0},
    dbFilterSlugsByWorld: {
      'Aegis': ['monster'],
    },
    dbFilterSourcesByWorld: {
      'Aegis': ['Homebrew'],
    },
    dbFilterShareModesByWorld: {
      'Aegis': ['shared'],
    },
    dbSortModeByWorld: {'Aegis': 'name', 'Baska': 'recent'},
    dbSearchByWorld: {'Aegis': 'goblin'},
    worldViewByWorld: {'Aegis': '{"pdfOpenPaths":["/tmp/a.pdf"]}'},
    viewTouchedByWorld: {'Aegis': 123},
  );

  late UiStateNotifier n;
  setUp(() => n = UiStateNotifier()..update((_) => seed));
  // Debounce timer'ini kapat — test bitince pending kalmasin.
  tearDown(() => n.dispose());

  test('forgetWorld drops every by-world trace of that world', () {
    n.forgetWorld('Aegis');

    final s = n.state;
    expect(s.dbOpenLeftByWorld.containsKey('Aegis'), isFalse);
    expect(s.dbOpenRightByWorld.containsKey('Aegis'), isFalse);
    expect(s.dbActiveLeftByWorld.containsKey('Aegis'), isFalse);
    expect(s.dbActiveRightByWorld.containsKey('Aegis'), isFalse);
    expect(s.dbFilterSlugsByWorld.containsKey('Aegis'), isFalse);
    expect(s.dbFilterSourcesByWorld.containsKey('Aegis'), isFalse);
    expect(s.dbFilterShareModesByWorld.containsKey('Aegis'), isFalse);
    expect(s.dbSortModeByWorld.containsKey('Aegis'), isFalse);
    expect(s.dbSearchByWorld.containsKey('Aegis'), isFalse);
    expect(s.worldViewByWorld.containsKey('Aegis'), isFalse);
    expect(s.viewTouchedByWorld.containsKey('Aegis'), isFalse);
  });

  test('forgetWorld leaves the other worlds alone', () {
    n.forgetWorld('Aegis');

    expect(n.state.dbOpenLeftByWorld['Baska'], ['e9']);
    expect(n.state.dbActiveLeftByWorld['Baska'], 1);
    expect(n.state.dbSortModeByWorld['Baska'], 'recent');
  });

  test('forgetWorld ignores the empty key (no active world)', () {
    n.forgetWorld('');
    expect(n.state.dbOpenLeftByWorld['Aegis'], ['e1']);
  });
}
