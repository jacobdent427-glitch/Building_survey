import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/project.dart';
import 'auth_service.dart';
import 'connectivity_service.dart';
import 'local_project_store.dart';

/// Pushes locally-saved projects up to Firestore whenever the device is
/// online. The local store (LocalProjectStore) is always the source of
/// truth, so the app is fully usable offline; this is a one-way
/// best-effort mirror on top of it, not a two-way sync.
///
/// Photos are intentionally NOT uploaded anywhere - Firebase Cloud Storage
/// requires the paid "Blaze" billing plan, which this project isn't on.
/// Photos stay device-local; only survey data (site/building/room/component
/// records) syncs to the cloud.
class SyncService {
  final LocalProjectStore _localStore;
  final ConnectivityService _connectivity;
  final AuthService _auth;
  StreamSubscription<bool>? _autoRetrySubscription;

  SyncService(this._localStore, this._connectivity, this._auth);

  bool get isConfigured {
    try {
      FirebaseFirestore.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> syncProject(Project project) async {
    if (!isConfigured) return false;
    if (!await _connectivity.isOnline()) return false;

    final user = await _auth.ensureSignedIn();
    if (user == null) return false;

    try {
      final cloudJson = project.toJson();
      cloudJson['uploadedByUid'] = user.uid;

      await FirebaseFirestore.instance
          .collection('projects')
          .doc(project.id)
          .set(cloudJson);

      project.synced = true;
      await _localStore.save(project);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Best-effort removal of the cloud copy of a project. Failures (offline,
  /// not configured, never synced in the first place) are swallowed - the
  /// local delete is what actually matters and always succeeds regardless.
  Future<void> deleteProject(String projectId) async {
    if (!isConfigured) return;
    if (!await _connectivity.isOnline()) return;
    try {
      await FirebaseFirestore.instance.collection('projects').doc(projectId).delete();
    } catch (_) {
      // Nothing to do - the local copy is already gone, which is what matters.
    }
  }

  Future<void> syncAllUnsyncedProjects() async {
    final projects = await _localStore.listAll();
    for (final project in projects.where((p) => !p.synced)) {
      await syncProject(project);
    }
  }

  /// Retries every unsynced project as soon as connectivity is available:
  /// once immediately (covers "was offline when the app started"), then
  /// again every time the device transitions from offline to online.
  void startAutoRetry() {
    unawaited(syncAllUnsyncedProjects());
    _autoRetrySubscription?.cancel();
    _autoRetrySubscription = _connectivity.onStatusChange
        .where((isOnline) => isOnline)
        .listen((_) => syncAllUnsyncedProjects());
  }

  void dispose() {
    _autoRetrySubscription?.cancel();
  }
}
