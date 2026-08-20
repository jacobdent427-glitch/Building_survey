import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/project.dart';

/// Persists projects as JSON files on-device, so the app is fully usable
/// with no network connection. This is the app's source of truth; cloud
/// sync (see SyncService) is a one-way push layered on top of it.
class LocalProjectStore {
  Future<Directory> _projectsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'projects'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Directory for a given project's photos: `projects/{id}/photos`
  Future<Directory> photosDir(String projectId) async {
    final projects = await _projectsDir();
    final dir = Directory(p.join(projects.path, projectId, 'photos'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _fileFor(String projectId) async {
    final dir = await _projectsDir();
    return File(p.join(dir.path, '$projectId.json'));
  }

  Future<void> save(Project project) async {
    final file = await _fileFor(project.id);
    await file.writeAsString(jsonEncode(project.toJson()));
  }

  Future<Project?> load(String projectId) async {
    final file = await _fileFor(projectId);
    if (!await file.exists()) return null;
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return Project.fromJson(json);
  }

  Future<List<Project>> listAll() async {
    final dir = await _projectsDir();
    final projects = <Project>[];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        final json =
            jsonDecode(await entity.readAsString()) as Map<String, dynamic>;
        projects.add(Project.fromJson(json));
      }
    }
    projects.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return projects;
  }

  Future<void> delete(String projectId) async {
    final file = await _fileFor(projectId);
    if (await file.exists()) await file.delete();
    final projects = await _projectsDir();
    final photos = Directory(p.join(projects.path, projectId));
    if (await photos.exists()) await photos.delete(recursive: true);
  }
}
