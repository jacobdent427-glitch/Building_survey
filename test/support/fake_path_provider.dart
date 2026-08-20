import 'dart:io';

import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Redirects LocalProjectStore's file I/O to a fresh temp directory for
/// each test, instead of hitting a real platform channel (which doesn't
/// exist in the plain `flutter test` VM environment).
class FakePathProviderPlatform extends PathProviderPlatform {
  final Directory root;
  FakePathProviderPlatform(this.root);

  @override
  Future<String?> getApplicationDocumentsPath() async => root.path;
}

/// Installs a fake path_provider backed by a fresh temp directory and
/// returns it so tests can clean it up afterwards.
Directory installFakePathProvider() {
  final dir = Directory.systemTemp.createTempSync('building_survey_test_');
  PathProviderPlatform.instance = FakePathProviderPlatform(dir);
  return dir;
}
