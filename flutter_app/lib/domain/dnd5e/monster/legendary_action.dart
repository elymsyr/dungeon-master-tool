import 'monster_action.dart';

/// Legendary action — costs slots from a shared pool spent between other
/// creatures' turns. [cost] is the number of legendary action slots consumed.
class LegendaryAction {
  final String name;
  final String description;
  final int cost;
  final MonsterAction inner;

  LegendaryAction._(this.name, this.description, this.cost, this.inner);

  factory LegendaryAction({
    required String name,
    String description = '',
    int cost = 1,
    required MonsterAction inner,
  }) {
    if (name.isEmpty) {
      throw ArgumentError('LegendaryAction.name must not be empty');
    }
    if (cost < 1) throw ArgumentError('LegendaryAction.cost must be >= 1');
    return LegendaryAction._(name, description, cost, inner);
  }
}
