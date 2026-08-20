import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'local_project_store.dart';

/// Captures a photo with the device camera and copies it into the project's
/// local photo folder, returning the path it was saved to.
class PhotoService {
  final ImagePicker _picker = ImagePicker();
  final LocalProjectStore _store;
  final _uuid = const Uuid();

  PhotoService(this._store);

  Future<String?> captureForProject(String projectId) async {
    final shot = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (shot == null) return null;

    final dir = await _store.photosDir(projectId);
    final ext = p.extension(shot.path).isNotEmpty
        ? p.extension(shot.path)
        : '.jpg';
    final destPath = p.join(dir.path, '${_uuid.v4()}$ext');
    await File(shot.path).copy(destPath);
    return destPath;
  }
}
