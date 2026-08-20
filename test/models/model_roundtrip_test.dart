import 'package:flutter_test/flutter_test.dart';

import 'package:building_survey_app/models/building.dart';
import 'package:building_survey_app/models/condition.dart';
import 'package:building_survey_app/models/project.dart';
import 'package:building_survey_app/models/room.dart';
import 'package:building_survey_app/models/surveyed_component.dart';

void main() {
  group('SurveyedComponent', () {
    test('round-trips every field through toJson/fromJson', () {
      final original = SurveyedComponent(
        id: 'c1',
        photoPaths: const ['photo1.jpg', 'photo2.jpg'],
        group: 'SUPERSTRUCTURES',
        system: 'EXTERNAL WALLS',
        element: 'Windows',
        subElement: 'Frames',
        component: 'uPVC frame',
        subComponent: 'uPVC frame - double glazed',
        hierarchyIndex: 42,
        quantity: 3.5,
        coreSystem: CoreSystem.core,
        conditionRating: ConditionRating.c,
        conditionPriority: ConditionPriority.p2,
        recordedAt: DateTime.utc(2026, 1, 15, 9, 30),
      );

      final restored = SurveyedComponent.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.photoPaths, original.photoPaths);
      expect(restored.group, original.group);
      expect(restored.subComponent, original.subComponent);
      expect(restored.hierarchyIndex, original.hierarchyIndex);
      expect(restored.quantity, original.quantity);
      expect(restored.coreSystem, original.coreSystem);
      expect(restored.conditionRating, original.conditionRating);
      expect(restored.conditionPriority, original.conditionPriority);
      expect(restored.recordedAt, original.recordedAt);
    });

    test('round-trips with zero photos (now optional)', () {
      final original = SurveyedComponent(
        id: 'c2',
        photoPaths: const [],
        group: 'G',
        system: 'S',
        element: 'E',
        subElement: 'SE',
        component: 'C',
        subComponent: 'SC',
        hierarchyIndex: 1,
        quantity: 1,
        coreSystem: CoreSystem.nonCore,
        conditionRating: ConditionRating.a,
        conditionPriority: ConditionPriority.p4,
        recordedAt: DateTime.utc(2026, 1, 1),
      );

      final restored = SurveyedComponent.fromJson(original.toJson());
      expect(restored.photoPaths, isEmpty);
    });
  });

  group('Room', () {
    test('round-trips reference, floor, what3words and nested components', () {
      final component = SurveyedComponent(
        id: 'c1',
        photoPaths: const [],
        group: 'G',
        system: 'S',
        element: 'E',
        subElement: 'SE',
        component: 'C',
        subComponent: 'SC',
        hierarchyIndex: 1,
        quantity: 1,
        coreSystem: CoreSystem.core,
        conditionRating: ConditionRating.b,
        conditionPriority: ConditionPriority.p1,
        recordedAt: DateTime.utc(2026, 1, 1),
      );
      final original = Room(
        id: 'r1',
        reference: 'Room 101',
        floor: '1st Floor',
        what3words: 'filled.count.soap',
        components: [component],
      );

      final restored = Room.fromJson(original.toJson());

      expect(restored.reference, 'Room 101');
      expect(restored.floor, '1st Floor');
      expect(restored.what3words, 'filled.count.soap');
      expect(restored.components, hasLength(1));
      expect(restored.components.first.id, 'c1');
    });

    test('defaults floor and what3words to empty string when absent', () {
      final restored = Room.fromJson({
        'id': 'r1',
        'reference': 'Room 1',
        'components': [],
      });
      expect(restored.floor, '');
      expect(restored.what3words, '');
    });
  });

  group('Building', () {
    test('round-trips reference, isExternal and nested rooms', () {
      final original = Building(
        id: 'b1',
        reference: 'External',
        isExternal: true,
        rooms: [Room(id: 'r1', reference: 'Yard')],
      );

      final restored = Building.fromJson(original.toJson());

      expect(restored.isExternal, isTrue);
      expect(restored.rooms, hasLength(1));
    });
  });

  group('Project', () {
    test('round-trips full nested structure and computes componentCount', () {
      final component = SurveyedComponent(
        id: 'c1',
        photoPaths: const [],
        group: 'G',
        system: 'S',
        element: 'E',
        subElement: 'SE',
        component: 'C',
        subComponent: 'SC',
        hierarchyIndex: 1,
        quantity: 1,
        coreSystem: CoreSystem.core,
        conditionRating: ConditionRating.a,
        conditionPriority: ConditionPriority.p1,
        recordedAt: DateTime.utc(2026, 1, 1),
      );
      final room = Room(id: 'r1', reference: 'Room 1', components: [component]);
      final building = Building(id: 'b1', reference: 'Block A', rooms: [room]);
      final original = Project(
        id: 'p1',
        siteRef: 'SITE-1',
        siteAddress: '1 Test Street',
        surveyorId: 'JD-1',
        createdAt: DateTime.utc(2026, 1, 1, 8),
        buildings: [building],
        synced: true,
      );

      final restored = Project.fromJson(original.toJson());

      expect(restored.siteRef, 'SITE-1');
      expect(restored.synced, isTrue);
      expect(restored.componentCount, 1);
      expect(restored.buildings.single.rooms.single.components.single.id, 'c1');
    });

    test('defaults synced to false when absent from JSON', () {
      final restored = Project.fromJson({
        'id': 'p1',
        'siteRef': 'S',
        'siteAddress': 'A',
        'surveyorId': 'JD',
        'createdAt': DateTime.utc(2026).toIso8601String(),
        'buildings': [],
      });
      expect(restored.synced, isFalse);
      expect(restored.componentCount, 0);
    });
  });
}
