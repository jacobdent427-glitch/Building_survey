import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/building.dart';
import '../models/condition.dart';
import '../models/project.dart';
import '../models/room.dart';
import '../models/surveyed_component.dart';
import '../services/local_project_store.dart';
import '../services/sync_service.dart';

/// Owns the currently open project, applies every survey mutation to it,
/// and persists to local storage (with a best-effort cloud sync attempt)
/// after each change. This is the single place UI screens go through to
/// change project data.
class ProjectController extends ChangeNotifier {
  final LocalProjectStore _store;
  final SyncService _sync;
  final _uuid = const Uuid();

  Project? _project;
  Project? get project => _project;

  ProjectController(this._store, this._sync);

  Future<Project> createProject({
    required String surveyorId,
    required String siteRef,
    required String siteAddress,
  }) async {
    final project = Project(
      id: _uuid.v4(),
      siteRef: siteRef,
      siteAddress: siteAddress,
      surveyorId: surveyorId,
      createdAt: DateTime.now(),
    );
    _project = project;
    await _persist();
    return project;
  }

  Future<void> openProject(Project project) async {
    _project = project;
    notifyListeners();
  }

  // --- Buildings ---------------------------------------------------------

  Building addBuilding({required String reference, required bool isExternal}) {
    final building = Building(
      id: _uuid.v4(),
      reference: isExternal ? 'External' : reference,
      isExternal: isExternal,
    );
    _project!.buildings.add(building);
    _persist();
    return building;
  }

  void updateBuilding(
    Building building, {
    required String reference,
    required bool isExternal,
  }) {
    building.reference = isExternal ? 'External' : reference;
    building.isExternal = isExternal;
    _persist();
  }

  void deleteBuilding(Building building) {
    _project!.buildings.remove(building);
    _persist();
  }

  // --- Rooms ---------------------------------------------------------

  Room addRoom(
    Building building, {
    required String reference,
    String floor = '',
    String what3words = '',
  }) {
    final room = Room(
      id: _uuid.v4(),
      reference: reference,
      floor: floor,
      what3words: what3words,
    );
    building.rooms.add(room);
    _persist();
    return room;
  }

  void updateRoom(
    Room room, {
    required String reference,
    String floor = '',
    String what3words = '',
  }) {
    room.reference = reference;
    room.floor = floor;
    room.what3words = what3words;
    _persist();
  }

  void deleteRoom(Building building, Room room) {
    building.rooms.remove(room);
    _persist();
  }

  // --- Components ---------------------------------------------------------

  SurveyedComponent addComponent(
    Room room, {
    required List<String> photoPaths,
    required String group,
    required String system,
    required String element,
    required String subElement,
    required String component,
    required String subComponent,
    required int hierarchyIndex,
    required double quantity,
    required CoreSystem coreSystem,
    required ConditionRating conditionRating,
    required ConditionPriority conditionPriority,
  }) {
    final surveyed = SurveyedComponent(
      id: _uuid.v4(),
      photoPaths: photoPaths,
      group: group,
      system: system,
      element: element,
      subElement: subElement,
      component: component,
      subComponent: subComponent,
      hierarchyIndex: hierarchyIndex,
      quantity: quantity,
      coreSystem: coreSystem,
      conditionRating: conditionRating,
      conditionPriority: conditionPriority,
      recordedAt: DateTime.now(),
    );
    room.components.add(surveyed);
    _persist();
    return surveyed;
  }

  void updateComponent(
    SurveyedComponent existing, {
    required List<String> photoPaths,
    required String group,
    required String system,
    required String element,
    required String subElement,
    required String component,
    required String subComponent,
    required int hierarchyIndex,
    required double quantity,
    required CoreSystem coreSystem,
    required ConditionRating conditionRating,
    required ConditionPriority conditionPriority,
  }) {
    existing
      ..photoPaths = photoPaths
      ..group = group
      ..system = system
      ..element = element
      ..subElement = subElement
      ..component = component
      ..subComponent = subComponent
      ..hierarchyIndex = hierarchyIndex
      ..quantity = quantity
      ..coreSystem = coreSystem
      ..conditionRating = conditionRating
      ..conditionPriority = conditionPriority;
    _persist();
  }

  void deleteComponent(Room room, SurveyedComponent component) {
    room.components.remove(component);
    _persist();
  }

  /// Every mutation already auto-saves; this is exposed so the UI can offer
  /// an explicit "Save" action (and retry a sync) on demand.
  Future<void> saveNow() => _persist();

  Future<void> _persist() async {
    final project = _project;
    if (project == null) return;
    project.synced = false;
    await _store.save(project);
    notifyListeners();
    // Best-effort: don't block the UI on network sync.
    unawaited(_sync.syncProject(project).then((_) => notifyListeners()));
  }
}
