import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;

import '../models/project.dart';
import 'auth_service.dart';
import 'connectivity_service.dart';
import 'local_project_store.dart';

/// Pushes locally-saved projects up to Firestore/Storage whenever the
/// device is online. The local store (LocalProjectStore) is always the
/// source of truth, so the app is fully usable offline; this is a one-way
/// best-effort mirror on top of it, not a two-way sync.
///
/// Photo uploads resume rather than restart: each project carries a
/// persisted local-path -> download-URL cache (Project.photoUrlCache) that's
/// saved to disk after every single photo upload succeeds, so if the app is
/// killed mid-sync, the next attempt only uploads what's still missing.
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
      for (final building in project.buildings) {
        for (final room in building.rooms) {
          for (final component in room.components) {
            for (final localPath in component.photoPaths) {
              if (project.photoUrlCache.containsKey(localPath)) continue;
              final file = File(localPath);
              if (!await file.exists()) continue;

              final ref = FirebaseStorage.instance.ref(
                  'projects/${project.id}/photos/${p.basename(localPath)}');
              await ref.putFile(file);
              final url = await ref.getDownloadURL();

              // Persist immediately: if the app is killed before the
              // project document write below, this upload still won't be
              // redone on the next attempt.
              project.photoUrlCache[localPath] = url;
              await _localStore.save(project);
            }
          }
        }
      }

      final cloudJson = project.toJson();
      _replacePhotoPaths(cloudJson, project.photoUrlCache);
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

  void _replacePhotoPaths(Map<String, dynamic> json, Map<String, String> urlCache) {
    for (final building in json['buildings'] as List) {
      for (final room in (building as Map<String, dynamic>)['rooms'] as List) {
        for (final component in (room as Map<String, dynamic>)['components'] as List) {
          final paths = (component as Map<String, dynamic>)['photoPaths'] as List;
          component['photoPaths'] =
              paths.map((path) => urlCache[path] ?? path).toList();
        }
      }
    }
  }

  Future<void> syncAllUnsyncedProjects() async {
    final projects = await _localStore.listAll();
    for (final project in projects.where((p) => !p.synced)) {
      await syncProject(project);
    }
  }

  /// Retries every unsynced project as soon as connectivity is available:
  /// once immediately (covers "was offline when the app started, or was
  /// killed mid-upload last session"), then again every time the device
  /// transitions from offline to online.
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
