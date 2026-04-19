/// Wizard steps per Doc 10.
enum CharacterCreationStep {
  startMode,
  classChoice,
  origin,
  abilities,
  alignment,
  details,
  review;

  bool get isFirst => this == CharacterCreationStep.startMode;
  bool get isLast => this == CharacterCreationStep.review;

  CharacterCreationStep? get next {
    final i = index;
    if (i + 1 >= CharacterCreationStep.values.length) return null;
    return CharacterCreationStep.values[i + 1];
  }

  CharacterCreationStep? get previous {
    final i = index;
    if (i == 0) return null;
    return CharacterCreationStep.values[i - 1];
  }
}
