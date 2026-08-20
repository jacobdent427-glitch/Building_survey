import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/auth_service.dart';
import 'services/connectivity_service.dart';
import 'services/csv_export_service.dart';
import 'services/hierarchy_repository.dart';
import 'services/local_project_store.dart';
import 'services/photo_service.dart';
import 'services/sync_service.dart';
import 'services/what3words_service.dart';
import 'state/project_controller.dart';
import 'screens/surveyor_entry_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cloud sync is optional: if Firebase isn't configured yet (or the device
  // has no connectivity), the app still runs fully in local-only mode.
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Not configured / failed to initialize - proceed offline-only.
  }

  final hierarchy = await HierarchyRepository.load();
  final localStore = LocalProjectStore();
  final connectivity = ConnectivityService();
  final auth = AuthService();
  final sync = SyncService(localStore, connectivity, auth);
  sync.startAutoRetry();

  runApp(BuildingSurveyApp(
    hierarchy: hierarchy,
    localStore: localStore,
    sync: sync,
  ));
}

class BuildingSurveyApp extends StatelessWidget {
  final HierarchyRepository hierarchy;
  final LocalProjectStore localStore;
  final SyncService sync;

  const BuildingSurveyApp({
    super.key,
    required this.hierarchy,
    required this.localStore,
    required this.sync,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<HierarchyRepository>.value(value: hierarchy),
        Provider<LocalProjectStore>.value(value: localStore),
        Provider<SyncService>.value(value: sync),
        Provider<PhotoService>(create: (_) => PhotoService(localStore)),
        Provider<CsvExportService>(create: (_) => CsvExportService(hierarchy)),
        Provider<What3WordsService>(create: (_) => What3WordsService()),
        ChangeNotifierProvider<ProjectController>(
          create: (_) => ProjectController(localStore, sync),
        ),
      ],
      child: MaterialApp(
        title: 'Building Survey',
        theme: AppTheme.light(),
        home: const SurveyorEntryScreen(),
      ),
    );
  }
}
