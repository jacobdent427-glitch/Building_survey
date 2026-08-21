import 'dart:io';
import 'dart:ui' show Rect;

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/building.dart';
import '../models/hierarchy_entry.dart';
import '../models/project.dart';
import '../models/room.dart';
import '../models/surveyed_component.dart';
import 'hierarchy_repository.dart';

/// Builds the survey export CSV, matching the "app rough output" template
/// column-for-column: one row per surveyed component, with the surveyor's
/// own entries first and the matched hierarchy-database lookup data
/// (RSL, SFG code, rate, maintenance frequencies, ...) appended afterwards.
///
/// Photos are captured into the app's private on-device storage - they
/// never reach the camera roll or anywhere else a person could browse to,
/// so a photo filename on its own means nothing to anyone who isn't looking
/// at the phone. To make the export self-contained, [exportAndShare] shares
/// a zip of the actual photo files alongside the CSV, named to match the
/// CSV's photo ref columns exactly.
class CsvExportService {
  final HierarchyRepository _hierarchy;

  CsvExportService(this._hierarchy);

  static const _freqOrder = [
    'freq_1h',
    'freq_2h',
    'freq_1d',
    'freq_1w',
    'freq_2w',
    'freq_1m',
    'freq_2m',
    'freq_3m',
    'freq_4m',
    'freq_6m',
    'freq_12m',
    'freq_13m',
    'freq_14m',
    'freq_18m',
    'freq_24m',
    'freq_36m',
    'freq_48m',
    'freq_60m',
    'freq_72m',
    'freq_84m',
    'freq_120m',
    'freq_10y',
    'freq_15y',
    'freq_20y',
    'freq_25y',
    'freq_0u',
  ];

  static const _header = [
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
  ];

  List<List<dynamic>> buildRows(Project project) {
    final rows = <List<dynamic>>[_header];

    for (final building in project.buildings) {
      final buildingRef = building.isExternal ? 'External' : building.reference;
      for (final room in building.rooms) {
        for (final c in room.components) {
          HierarchyEntry? entry;
          try {
            entry = _hierarchy.entryByIndex(c.hierarchyIndex);
          } catch (_) {
            entry = null;
          }

          final photos = List<String>.generate(3, (i) {
            if (i >= c.photoPaths.length) return '';
            return _photoExportName(building, room, c, i);
          });

          rows.add([
            project.siteRef,
            project.surveyorId,
            buildingRef,
            room.floor,
            room.reference,
            photos[0],
            photos[1],
            photos[2],
            c.group,
            c.system,
            c.element,
            c.subElement,
            c.component,
            c.subComponent,
            c.quantity,
            c.coreSystem.label,
            c.conditionRating.label,
            c.conditionPriority.label,
            entry?.rsl ?? '',
            entry?.sfgCode ?? '',
            entry?.unit ?? '',
            entry?.rate ?? '',
            entry?.pricingSource ?? '',
            entry?.statutory ?? '',
            entry?.sfgTitle ?? '',
            entry?.skillSet ?? '',
            entry?.annualTiming ?? '',
            for (final key in _freqOrder) entry?.frequencies[key] ?? '',
          ]);
        }
      }
    }
    return rows;
  }

  /// The filename a photo gets in the export - both in the CSV's photo ref
  /// columns and in the zip built by [writePhotosZipToTempFile]. Purely a
  /// function of (building, room, component, photo index), so both call
  /// sites always agree without needing to share any state: readable
  /// (building/room/component name baked in) and guaranteed unique (a slice
  /// of the component's own id, which nothing else shares).
  String _photoExportName(Building building, Room room, SurveyedComponent c, int photoIndex) {
    final buildingRef = building.isExternal ? 'External' : building.reference;
    final componentName = c.subComponent.isNotEmpty ? c.subComponent : c.component;
    final base = [
      buildingRef,
      room.reference,
      componentName,
      '${photoIndex + 1}',
    ].map(_sanitizeForFilename).join('_');
    final shortId = c.id.length >= 6 ? c.id.substring(0, 6) : c.id;
    final path = photoIndex < c.photoPaths.length ? c.photoPaths[photoIndex] : '';
    final ext = p.extension(path).isNotEmpty ? p.extension(path) : '.jpg';
    return '${base}_$shortId$ext';
  }

  String _sanitizeForFilename(String value) =>
      value.trim().replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-');

  Future<File> writeToTempFile(Project project) async {
    final csv = const ListToCsvConverter().convert(buildRows(project));
    final dir = await getTemporaryDirectory();
    final safeSiteRef = project.siteRef.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final file = File(
      p.join(dir.path, 'survey_${safeSiteRef}_${_shortId(project.id)}.csv'),
    );
    return file.writeAsString(csv);
  }

  /// First 8 characters of an id (real project ids are UUIDs, always longer
  /// than that), falling back to the whole id if it's shorter - avoids a
  /// RangeError on the odd short id, e.g. in tests.
  String _shortId(String id) => id.length >= 8 ? id.substring(0, 8) : id;

  /// Zips every photo actually recorded against this project, each named to
  /// match its "photo N ref" cell in the CSV. Returns null if the project
  /// has no photos at all, or none of the referenced files still exist on
  /// disk (e.g. app data was cleared) - nothing useful to share in that case.
  Future<File?> writePhotosZipToTempFile(Project project) async {
    final archive = Archive();

    for (final building in project.buildings) {
      for (final room in building.rooms) {
        for (final c in room.components) {
          for (var i = 0; i < c.photoPaths.length; i++) {
            final file = File(c.photoPaths[i]);
            if (!await file.exists()) continue;
            final bytes = await file.readAsBytes();
            archive.addFile(
              ArchiveFile(_photoExportName(building, room, c, i), bytes.length, bytes),
            );
          }
        }
      }
    }

    if (archive.isEmpty) return null;

    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) return null;

    final dir = await getTemporaryDirectory();
    final safeSiteRef = project.siteRef.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final file = File(
      p.join(dir.path, 'survey_${safeSiteRef}_${_shortId(project.id)}_photos.zip'),
    );
    return file.writeAsBytes(zipBytes);
  }

  /// [sharePositionOrigin] anchors the share sheet on screen. iPadOS
  /// requires this (it presents the sheet as a popover pointing at that
  /// rect) - without it, sharing silently does nothing on iPad specifically,
  /// even though iPhone and Android don't need it.
  Future<void> exportAndShare(Project project, {Rect? sharePositionOrigin}) async {
    final csvFile = await writeToTempFile(project);
    final photosZip = await writePhotosZipToTempFile(project);

    await Share.shareXFiles(
      [XFile(csvFile.path), if (photosZip != null) XFile(photosZip.path)],
      subject: 'Survey export - ${project.siteRef}',
      sharePositionOrigin: sharePositionOrigin,
    );
  }
}
