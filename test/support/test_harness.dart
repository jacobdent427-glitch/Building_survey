import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:building_survey_app/services/auth_service.dart';
import 'package:building_survey_app/services/connectivity_service.dart';
import 'package:building_survey_app/services/csv_export_service.dart';
import 'package:building_survey_app/services/hierarchy_repository.dart';
import 'package:building_survey_app/services/local_project_store.dart';
import 'package:building_survey_app/services/photo_service.dart';
import 'package:building_survey_app/services/sync_service.dart';
import 'package:building_survey_app/services/what3words_service.dart';
import 'package:building_survey_app/state/project_controller.dart';
import 'package:building_survey_app/theme/app_theme.dart';

/// Everything a screen test needs, built the same way main.dart wires the
/// real app - minus calling Firebase.initializeApp(), so SyncService quietly
/// reports itself unconfigured (isConfigured == false) instead of touching
/// a real network or platform channel. That mirrors exactly what happens on
/// a device with no Firebase config, which the app already has to handle.
class TestHarness {
  final HierarchyRepository hierarchy;
  final LocalProjectStore localStore;
  final SyncService sync;
  final ProjectController controller;

  TestHarness._({
    required this.hierarchy,
    required this.localStore,
    required this.sync,
    required this.controller,
  });

  /// For test files with a single test: loads everything, including the
  /// hierarchy database. Only awaited from setUpAll/setUp - never from
  /// inside a testWidgets body, where awaiting real async work before the
  /// first pump() can deadlock the test binding's event loop.
  static Future<TestHarness> create() async =>
      withHierarchy(await HierarchyRepository.load());

  /// For test files with multiple tests that each want a fresh
  /// ProjectController/LocalProjectStore: load the (expensive, read-only)
  /// hierarchy once in setUpAll, then build a fresh harness per test
  /// synchronously - no async work, so it's safe to call anywhere.
  static TestHarness withHierarchy(HierarchyRepository hierarchy) {
    final localStore = LocalProjectStore();
    final sync = SyncService(localStore, ConnectivityService(), AuthService());
    final controller = ProjectController(localStore, sync);
    return TestHarness._(
      hierarchy: hierarchy,
      localStore: localStore,
      sync: sync,
      controller: controller,
    );
  }

  Widget wrap(Widget home) {
    return MultiProvider(
      providers: [
        Provider<HierarchyRepository>.value(value: hierarchy),
        Provider<LocalProjectStore>.value(value: localStore),
        Provider<SyncService>.value(value: sync),
        Provider<PhotoService>(create: (_) => PhotoService(localStore)),
        Provider<CsvExportService>(create: (_) => CsvExportService(hierarchy)),
        Provider<What3WordsService>(create: (_) => What3WordsService()),
        ChangeNotifierProvider<ProjectController>.value(value: controller),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: home),
    );
  }
}
