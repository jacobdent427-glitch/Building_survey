/// One row of the maintenance hierarchy database (Group -> System -> Element
/// -> Sub-Element -> Component -> Sub-Component), plus the RSL/costing/
/// maintenance-frequency data that gets carried through to the CSV export
/// but is never shown to the surveyor in the app itself.
class HierarchyEntry {
  final int index;
  final String group;
  final String system;
  final String element;
  final String subElement;
  final String component;
  final String subComponent;

  final String rsl;
  final String sfgCode;
  final String unit;
  final String rate;
  final String pricingSource;
  final String statutory;
  final String sfgTitle;
  final String skillSet;
  final String annualTiming;

  /// Maintenance-frequency columns, keyed by their original header
  /// (freq_1h, freq_2h, ... freq_25y, freq_0u), preserved verbatim for export.
  final Map<String, String> frequencies;

  HierarchyEntry({
    required this.index,
    required this.group,
    required this.system,
    required this.element,
    required this.subElement,
    required this.component,
    required this.subComponent,
    required this.rsl,
    required this.sfgCode,
    required this.unit,
    required this.rate,
    required this.pricingSource,
    required this.statutory,
    required this.sfgTitle,
    required this.skillSet,
    required this.annualTiming,
    required this.frequencies,
  });

  factory HierarchyEntry.fromCsvRow(Map<String, String> row) {
    const freqKeys = [
      'freq_1h',
      'freq_2h',
      'freq_1d',
      'freq_1w',
      'freq_2w',
      'freq_1m',
      'freq_2m',
      'freq_3m',
      'freq_4m',
      'freq_6m',
      'freq_12m',
      'freq_13m',
      'freq_14m',
      'freq_18m',
      'freq_24m',
      'freq_36m',
      'freq_48m',
      'freq_60m',
      'freq_72m',
      'freq_84m',
      'freq_120m',
      'freq_10y',
      'freq_15y',
      'freq_20y',
      'freq_25y',
      'freq_0u',
    ];
    return HierarchyEntry(
      index: int.tryParse(row['index'] ?? '') ?? 0,
      group: row['group'] ?? '',
      system: row['system'] ?? '',
      element: row['element'] ?? '',
      subElement: row['sub_element'] ?? '',
      component: row['component'] ?? '',
      subComponent: row['sub_component'] ?? '',
      rsl: row['rsl'] ?? '',
      sfgCode: row['sfg_code'] ?? '',
      unit: row['unit'] ?? '',
      rate: row['rate'] ?? '',
      pricingSource: row['pricing_source'] ?? '',
      statutory: row['statutory'] ?? '',
      sfgTitle: row['sfg_title'] ?? '',
      skillSet: row['skill_set'] ?? '',
      annualTiming: row['annual_timing'] ?? '',
      frequencies: {for (final k in freqKeys) k: row[k] ?? ''},
    );
  }

  /// The 6-level classification path, used to disambiguate rows that share
  /// the same text path but differ in unit/rate (this database is not
  /// perfectly unique on name alone).
  String get pathKey =>
      '$group|$system|$element|$subElement|$component|$subComponent';
}
