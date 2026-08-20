import 'dart:io';
import 'dart:ui' show Rect;

import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/hierarchy_entry.dart';
import '../models/project.dart';
import 'hierarchy_repository.dart';

/// Builds the survey export CSV, matching the "app rough output" template
/// column-for-column: one row per surveyed component, with the surveyor's
/// own entries first and the matched hierarchy-database lookup data
/// (RSL, SFG code, rate, maintenance frequencies, ...) appended afterwards.
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
    'site ref',
    'surveyor ref',
    'building ref',
    'floor',
    'room',
    'photo 1 ref',
    'photo 2 ref',
    'photo 3 ref',
    'group',
    'system',
    'element',
    'sub-element',
    'component',
    'sub component',
    'qty',
    'core/system',
    'surveyor condition rating a-d',
    'surveyor condition priority 1-4',
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

          final photos = [
            c.photoPaths.isNotEmpty ? p.basename(c.photoPaths[0]) : '',
            c.photoPaths.length > 1 ? p.basename(c.photoPaths[1]) : '',
            c.photoPaths.length > 2 ? p.basename(c.photoPaths[2]) : '',
          ];

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

  Future<File> writeToTempFile(Project project) async {
    final csv = const ListToCsvConverter().convert(buildRows(project));
    final dir = await getTemporaryDirectory();
    final safeSiteRef = project.siteRef.replaceAll(
      RegExp(r'[^A-Za-z0-9_-]'),
      '_',
    );
    final file = File(
      p.join(
        dir.path,
        'survey_${safeSiteRef}_${project.id.substring(0, 8)}.csv',
      ),
    );
    return file.writeAsString(csv);
  }

  /// [sharePositionOrigin] anchors the share sheet on screen. iPadOS
  /// requires this (it presents the sheet as a popover pointing at that
  /// rect) - without it, sharing silently does nothing on iPad specifically,
  /// even though iPhone and Android don't need it.
  Future<void> exportAndShare(
    Project project, {
    Rect? sharePositionOrigin,
  }) async {
    final file = await writeToTempFile(project);
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Survey export - ${project.siteRef}',
      sharePositionOrigin: sharePositionOrigin,
    );
  }
}
