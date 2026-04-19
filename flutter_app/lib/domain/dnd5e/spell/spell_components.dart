/// Sealed spell component. Material components include an optional
/// consumed-flag and a listed cost in copper; Verbal/Somatic are singletons.
sealed class SpellComponent {
  const SpellComponent();
}

class VerbalComponent extends SpellComponent {
  const VerbalComponent();
  @override
  bool operator ==(Object other) => other is VerbalComponent;
  @override
  int get hashCode => (VerbalComponent).hashCode;
  @override
  String toString() => 'V';
}

class SomaticComponent extends SpellComponent {
  const SomaticComponent();
  @override
  bool operator ==(Object other) => other is SomaticComponent;
  @override
  int get hashCode => (SomaticComponent).hashCode;
  @override
  String toString() => 'S';
}

class MaterialComponent extends SpellComponent {
  final String description;
  final int? costCp;
  final bool consumed;

  MaterialComponent._(this.description, this.costCp, this.consumed);

  factory MaterialComponent({
    required String description,
    int? costCp,
    bool consumed = false,
  }) {
    if (description.isEmpty) {
      throw ArgumentError('MaterialComponent.description must not be empty');
    }
    if (costCp != null && costCp < 0) {
      throw ArgumentError('MaterialComponent.costCp must be >= 0 (or null)');
    }
    return MaterialComponent._(description, costCp, consumed);
  }

  @override
  bool operator ==(Object other) =>
      other is MaterialComponent &&
      other.description == description &&
      other.costCp == costCp &&
      other.consumed == consumed;

  @override
  int get hashCode => Object.hash(description, costCp, consumed);

  @override
  String toString() =>
      'M(${consumed ? 'consumed ' : ''}${costCp == null ? '' : '$costCp cp '}'
      '$description)';
}
