import 'package:flutter_test/flutter_test.dart';

import 'package:building_survey_app/models/building.dart';
import 'package:building_survey_app/models/condition.dart';
import 'package:building_survey_app/models/project.dart';
import 'package:building_survey_app/models/room.dart';
import 'package:building_survey_app/models/surveyed_component.dart';
import 'package:building_survey_app/services/csv_export_service.dart';
import 'package:building_survey_app/services/hierarchy_repository.dart';

void main() {
  testWidgets('hierarchy database loads and cascades correctly', (tester) async {
    final hierarchy = await HierarchyRepository.load();
    expect(hierarchy.length, greaterThan(17000));

    final groups = hierarchy.groups();
    expect(groups, isNotEmpty);

    final systems = hierarchy.systems(groups.first);
    expect(systems, isNotEmpty);
  });

  testWidgets('CSV export produces one row per surveyed component with a lookup match',
      (tester) async {
    final hierarchy = await HierarchyRepository.load();
    final entry = hierarchy.entryByIndex(1);

    final component = SurveyedComponent(
      id: 'c1',
      photoPaths: const ['a.jpg', 'b.jpg', 'c.jpg'],
      group: entry.group,
      system: entry.system,
      element: entry.element,
      subElement: entry.subElement,
      component: entry.component,
      subComponent: entry.subComponent,
      hierarchyIndex: entry.index,
      quantity: 2,
      coreSystem: CoreSystem.core,
      conditionRating: ConditionRating.b,
      conditionPriority: ConditionPriority.p2,
      recordedAt: DateTime(2026, 1, 1),
    );
    final room = Room(id: 'r1', reference: 'Room 1', components: [component]);
    final building = Building(id: 'b1', reference: 'Block A', rooms: [room]);

    final project = Project(
      id: 'test-project',
      siteRef: 'SITE-1',
      siteAddress: '1 Test Street',
      surveyorId: 'JD-1',
      createdAt: DateTime(2026, 1, 1),
      buildings: [building],
    );

    final rows = CsvExportService(hierarchy).buildRows(project);
    expect(rows.length, 2); // header + 1 component row
    expect(rows[1][8], entry.group); // 'group' column
    expect(rows[1][18], entry.rsl); // 'RSL' column, pulled from the lookup
  });
}
