import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/hierarchy_entry.dart';

/// Loads the bundled maintenance-hierarchy database once at startup and
/// answers the cascading "what are the valid next choices" queries the
/// component-capture picker needs (Group -> System -> Element -> Sub-Element
/// -> Component -> Sub-Component), preserving first-seen order from the
/// source spreadsheet rather than sorting alphabetically.
class HierarchyRepository {
  final List<HierarchyEntry> _entries;

  /// Number of 6-level paths in the source database that repeat under more
  /// than one row (same Group..Sub-Component text, different unit/rate/RSL).
  /// Computed once at load time since it needs a full pass anyway; used by
  /// the disambiguation UI's tests as a cheap way to confirm ambiguous
  /// paths genuinely exist, without a slow brute-force cascade search.
  final int duplicatePathCount;

  HierarchyRepository._(this._entries, this.duplicatePathCount);

  static Future<HierarchyRepository> load() async {
    final raw = await rootBundle.loadString('assets/data/hierarchy.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final header = (data['header'] as List).map((h) => h.toString()).toList();
    final rows = data['rows'] as List;

    final entries = <HierarchyEntry>[];
    for (final row in rows) {
      final rowList = row as List;
      final map = <String, String>{};
      for (var i = 0; i < header.length && i < rowList.length; i++) {
        map[header[i]] = rowList[i]?.toString() ?? '';
      }
      entries.add(HierarchyEntry.fromCsvRow(map));
    }

    final pathCounts = <String, int>{};
    for (final e in entries) {
      pathCounts[e.pathKey] = (pathCounts[e.pathKey] ?? 0) + 1;
    }
    final duplicatePathCount = pathCounts.values
        .where((count) => count > 1)
        .length;

    return HierarchyRepository._(entries, duplicatePathCount);
  }

  int get length => _entries.length;

  List<String> _distinctInOrder(Iterable<String> values) {
    final seen = <String>{};
    final out = <String>[];
    for (final v in values) {
      if (v.isEmpty) continue;
      if (seen.add(v)) out.add(v);
    }
    return out;
  }

  List<String> groups() => _distinctInOrder(_entries.map((e) => e.group));

  List<String> systems(String group) => _distinctInOrder(
    _entries.where((e) => e.group == group).map((e) => e.system),
  );

  List<String> elements(String group, String system) => _distinctInOrder(
    _entries
        .where((e) => e.group == group && e.system == system)
        .map((e) => e.element),
  );

  List<String> subElements(String group, String system, String element) =>
      _distinctInOrder(
        _entries
            .where(
              (e) =>
                  e.group == group &&
                  e.system == system &&
                  e.element == element,
            )
            .map((e) => e.subElement),
      );

  List<String> components(
    String group,
    String system,
    String element,
    String subElement,
  ) => _distinctInOrder(
    _entries
        .where(
          (e) =>
              e.group == group &&
              e.system == system &&
              e.element == element &&
              e.subElement == subElement,
        )
        .map((e) => e.component),
  );

  List<String> subComponents(
    String group,
    String system,
    String element,
    String subElement,
    String component,
  ) => _distinctInOrder(
    _entries
        .where(
          (e) =>
              e.group == group &&
              e.system == system &&
              e.element == element &&
              e.subElement == subElement &&
              e.component == component,
        )
        .map((e) => e.subComponent),
  );

  /// All database rows matching a fully-specified 6-level path. Usually one
  /// row, but the source database has ~1700 paths that repeat with a
  /// different unit/rate/RSL, so callers must handle more than one result.
  List<HierarchyEntry> matchingEntries(
    String group,
    String system,
    String element,
    String subElement,
    String component,
    String subComponent,
  ) => _entries
      .where(
        (e) =>
            e.group == group &&
            e.system == system &&
            e.element == element &&
            e.subElement == subElement &&
            e.component == component &&
            e.subComponent == subComponent,
      )
      .toList();

  HierarchyEntry entryByIndex(int index) =>
      _entries.firstWhere((e) => e.index == index);

  /// One entry known to belong to a duplicated 6-level path, or null if the
  /// database happens to have no duplicates. Exists to give tests a cheap,
  /// reliable way to exercise the disambiguation path without a brute-force
  /// search through the whole cascade.
  HierarchyEntry? sampleAmbiguousEntry() {
    final counts = <String, int>{};
    for (final e in _entries) {
      counts[e.pathKey] = (counts[e.pathKey] ?? 0) + 1;
    }
    for (final e in _entries) {
      if ((counts[e.pathKey] ?? 0) > 1) return e;
    }
    return null;
  }
}
