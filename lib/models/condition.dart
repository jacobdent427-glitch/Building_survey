/// Surveyor's visual condition grade for a component, A (best) to D (worst).
enum ConditionRating {
  a('A'),
  b('B'),
  c('C'),
  d('D');

  final String label;
  const ConditionRating(this.label);

  static ConditionRating fromLabel(String label) =>
      ConditionRating.values.firstWhere((e) => e.label == label);
}

/// Surveyor's repair/renewal priority for a component, 1 (urgent) to 4 (low).
enum ConditionPriority {
  p1('1'),
  p2('2'),
  p3('3'),
  p4('4');

  final String label;
  const ConditionPriority(this.label);

  static ConditionPriority fromLabel(String label) =>
      ConditionPriority.values.firstWhere((e) => e.label == label);
}

enum CoreSystem {
  core('Core'),
  nonCore('Non-core');

  final String label;
  const CoreSystem(this.label);

  static CoreSystem fromLabel(String label) =>
      CoreSystem.values.firstWhere((e) => e.label == label);
}
