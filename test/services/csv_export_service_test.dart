import 'package:flutter_test/flutter_test.dart';

import 'package:building_survey_app/models/building.dart';
import 'package:building_survey_app/models/condition.dart';
import 'package:building_survey_app/models/hierarchy_entry.dart';
import 'package:building_survey_app/models/project.dart';
import 'package:building_survey_app/models/room.dart';
import 'package:building_survey_app/models/surveyed_component.dart';
import 'package:building_survey_app/services/csv_export_service.dart';
import 'package:building_survey_app/services/hierarchy_repository.dart';

SurveyedComponent _componentFor(HierarchyEntry entry, {String id = 'c1'}) =>
    SurveyedComponent(
      id: id,
      photoPaths: const ['a.jpg', 'b.jpg'],
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
      recordedAt: DateTime.utc(2026, 1, 1),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HierarchyRepository hierarchy;

  setUpAll(() async {
    hierarchy = await HierarchyRepository.load();
  });

  test('header row matches the app-rough-output column layout exactly', () {
    final project = Project(
      id: 'p1',
      siteRef: 'S',
      siteAddress: 'A',
      surveyorId: 'JD',
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final rows = CsvExportService(hierarchy).buildRows(project);

    expect(rows.first, [
      'Site Ref',
      'Surveyor Ref',
      'Building Ref',
      'Floor',
      'Room',
      'Photo 1 Ref',
      'Photo 2 Ref',
      'Photo 3 Ref',
      'Group',
      'System',
      'Element',
      'Sub-Element',
      'Component',
      'Sub Component',
      'Qty',
      'Core/System',
      'Surveyor Condition Rating a-d',
      'Surveyor Condition Priority 1-4',
      'RSL',
      'SFG Code',
      'Unit',
      'Rate',
      'Pricing Source',
      'Statutory / Non-Statutory',
      'SFG Title',
      'Skill Set',
      'Annual Timing',
      '1H',
      '2H',
      '1D',
      '1W',
      '2W',
      '1M',
      '2M',
      '3M',
      '4M',
      '6M',
      '12M',
      '13M',
      '14M',
      '18M',
      '24M',
      '36M',
      '48M',
      '60M',
      '72M',
      '84M',
      '120M',
      '10Y',
      '15Y',
      '20Y',
      '25Y',
      '0U',
    ]);
  });

  test('an empty project produces only the header row', () {
    final project = Project(
      id: 'p1',
      siteRef: 'S',
      siteAddress: 'A',
      surveyorId: 'JD',
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final rows = CsvExportService(hierarchy).buildRows(project);
    expect(rows, hasLength(1));
  });

  test('one row per component, with survey fields and hierarchy lookup fields both present', () {
    final entry = hierarchy.entryByIndex(1);
    final component = _componentFor(entry);
    final room = Room(
      id: 'r1',
      reference: 'Room 1',
      floor: '2nd Floor',
      components: [component],
    );
    final building = Building(id: 'b1', reference: 'Block A', rooms: [room]);
    final project = Project(
      id: 'p1',
      siteRef: 'SITE-REF-1',
      siteAddress: '1 Test Street',
      surveyorId: 'JD-1',
      createdAt: DateTime.utc(2026, 1, 1),
      buildings: [building],
    );

    final rows = CsvExportService(hierarchy).buildRows(project);
    expect(rows, hasLength(2));

    final row = rows[1];
    expect(row[0], 'SITE-REF-1'); // site ref
    expect(row[1], 'JD-1'); // surveyor ref
    expect(row[2], 'Block A'); // building ref
    expect(row[3], '2nd Floor'); // floor
    expect(row[4], 'Room 1'); // room
    expect(row[5], 'a.jpg'); // photo 1 ref (basename only)
    expect(row[6], 'b.jpg'); // photo 2 ref
    expect(row[7], ''); // photo 3 ref - only 2 photos given
    expect(row[8], entry.group);
    expect(row[13], entry.subComponent);
    expect(row[14], 2.0); // qty
    expect(row[15], 'Core'); // core/system
    expect(row[16], 'B'); // condition rating
    expect(row[17], '2'); // condition priority
    expect(row[18], entry.rsl); // looked-up RSL
    expect(row[19], entry.sfgCode); // looked-up SFG code
  });

  test('an External building is labelled "External" in the export regardless of its reference', () {
    final entry = hierarchy.entryByIndex(1);
    final room = Room(
      id: 'r1',
      reference: 'Yard',
      components: [_componentFor(entry)],
    );
    final building = Building(
      id: 'b1',
      reference: 'External',
      isExternal: true,
      rooms: [room],
    );
    final project = Project(
      id: 'p1',
      siteRef: 'S',
      siteAddress: 'A',
      surveyorId: 'JD',
      createdAt: DateTime.utc(2026, 1, 1),
      buildings: [building],
    );

    final rows = CsvExportService(hierarchy).buildRows(project);
    expect(rows[1][2], 'External');
  });

  test('multiple buildings/rooms/components each produce their own row', () {
    final entry = hierarchy.entryByIndex(1);
    final roomA = Room(
      id: 'rA',
      reference: 'Room A',
      components: [
        _componentFor(entry, id: 'c1'),
        _componentFor(entry, id: 'c2'),
      ],
    );
    final roomB = Room(
      id: 'rB',
      reference: 'Room B',
      components: [_componentFor(entry, id: 'c3')],
    );
    final buildingA = Building(id: 'bA', reference: 'Block A', rooms: [roomA]);
    final buildingB = Building(id: 'bB', reference: 'Block B', rooms: [roomB]);
    final project = Project(
      id: 'p1',
      siteRef: 'S',
      siteAddress: 'A',
      surveyorId: 'JD',
      createdAt: DateTime.utc(2026, 1, 1),
      buildings: [buildingA, buildingB],
    );

    final rows = CsvExportService(hierarchy).buildRows(project);
    expect(rows, hasLength(4)); // header + 3 components
  });

  test('a component whose hierarchy row can no longer be found exports blank lookup fields, not a crash', () {
    final component = SurveyedComponent(
      id: 'c1',
      photoPaths: const [],
      group: 'G',
      system: 'S',
      element: 'E',
      subElement: 'SE',
      component: 'C',
      subComponent: 'SC',
      hierarchyIndex: -1, // does not exist in the database
      quantity: 1,
      coreSystem: CoreSystem.core,
      conditionRating: ConditionRating.a,
      conditionPriority: ConditionPriority.p1,
      recordedAt: DateTime.utc(2026, 1, 1),
    );
    final room = Room(id: 'r1', reference: 'Room 1', components: [component]);
    final building = Building(id: 'b1', reference: 'Block A', rooms: [room]);
    final project = Project(
      id: 'p1',
      siteRef: 'S',
      siteAddress: 'A',
      surveyorId: 'JD',
      createdAt: DateTime.utc(2026, 1, 1),
      buildings: [building],
    );

    final rows = CsvExportService(hierarchy).buildRows(project);
    expect(rows[1][18], ''); // RSL blank
    expect(rows[1][19], ''); // SFG code blank
  });
}
