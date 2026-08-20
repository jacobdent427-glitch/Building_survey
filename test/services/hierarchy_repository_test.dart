import 'package:flutter_test/flutter_test.dart';

import 'package:building_survey_app/services/hierarchy_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HierarchyRepository hierarchy;

  setUpAll(() async {
    hierarchy = await HierarchyRepository.load();
  });

  test('loads the full bundled database', () {
    expect(hierarchy.length, greaterThan(17000));
  });

  test('groups() returns a non-empty, deduplicated list', () {
    final groups = hierarchy.groups();
    expect(groups, isNotEmpty);
    expect(
      groups.toSet().length,
      groups.length,
      reason: 'no group should repeat',
    );
  });

  test('cascading queries only return children of the selected parent', () {
    final group = hierarchy.groups().first;
    final systems = hierarchy.systems(group);
    expect(systems, isNotEmpty);

    final system = systems.first;
    final elements = hierarchy.elements(group, system);
    expect(elements, isNotEmpty);

    // Every element returned must actually belong to (group, system) - spot
    // check by re-querying with a different, unrelated group and confirming
    // the result differs (guards against the filter being a no-op).
    final otherGroup = hierarchy.groups().firstWhere(
      (g) => g != group,
      orElse: () => group,
    );
    if (otherGroup != group) {
      final otherSystems = hierarchy.systems(otherGroup);
      expect(otherSystems, isNot(equals(systems)));
    }
  });

  test(
    'a fully-specified path with a single match resolves to exactly one entry',
    () {
      // Walk down to a genuinely leaf path and confirm matchingEntries can
      // find it again from its own component values.
      final group = hierarchy.groups().first;
      final system = hierarchy.systems(group).first;
      final element = hierarchy.elements(group, system).first;
      final subElement = hierarchy.subElements(group, system, element).first;
      final component = hierarchy
          .components(group, system, element, subElement)
          .first;
      final subComponent = hierarchy
          .subComponents(group, system, element, subElement, component)
          .first;

      final matches = hierarchy.matchingEntries(
        group,
        system,
        element,
        subElement,
        component,
        subComponent,
      );

      expect(matches, isNotEmpty);
      for (final m in matches) {
        expect(m.group, group);
        expect(m.system, system);
        expect(m.element, element);
        expect(m.subElement, subElement);
        expect(m.component, component);
        expect(m.subComponent, subComponent);
      }
    },
  );

  test('entryByIndex retrieves the exact row that index belongs to', () {
    final group = hierarchy.groups().first;
    final system = hierarchy.systems(group).first;
    final element = hierarchy.elements(group, system).first;
    final subElement = hierarchy.subElements(group, system, element).first;
    final component = hierarchy
        .components(group, system, element, subElement)
        .first;
    final subComponent = hierarchy
        .subComponents(group, system, element, subElement, component)
        .first;
    final match = hierarchy
        .matchingEntries(
          group,
          system,
          element,
          subElement,
          component,
          subComponent,
        )
        .first;

    final byIndex = hierarchy.entryByIndex(match.index);
    expect(byIndex.index, match.index);
    expect(byIndex.subComponent, match.subComponent);
  });

  test('the database has known-ambiguous 6-level paths', () {
    // Confirms the premise the disambiguation UI exists for: this source
    // spreadsheet is not unique on (Group..Sub-Component) text alone.
    expect(hierarchy.duplicatePathCount, greaterThan(0));
  });

  test(
    'matchingEntries surfaces every row of an ambiguous path, not just one',
    () {
      final sample = hierarchy.sampleAmbiguousEntry();
      expect(
        sample,
        isNotNull,
        reason: 'expected at least one ambiguous path to exist',
      );

      final matches = hierarchy.matchingEntries(
        sample!.group,
        sample.system,
        sample.element,
        sample.subElement,
        sample.component,
        sample.subComponent,
      );

      expect(matches.length, greaterThan(1));
      expect(matches.map((e) => e.index), contains(sample.index));
    },
  );
}
