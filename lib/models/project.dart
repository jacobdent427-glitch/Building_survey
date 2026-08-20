import 'building.dart';

/// A single survey project: one site, one surveyor session, made up of
/// buildings (or "external"), each with rooms, each with surveyed components.
class Project {
  final String id;
  final String siteRef;
  final String siteAddress;
  final String surveyorId;
  final DateTime createdAt;
  final List<Building> buildings;

  /// True once every change in this project has been pushed to the cloud.
  bool synced;

  Project({
    required this.id,
    required this.siteRef,
    required this.siteAddress,
    required this.surveyorId,
    required this.createdAt,
    List<Building>? buildings,
    this.synced = false,
  }) : buildings = buildings ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'siteRef': siteRef,
    'siteAddress': siteAddress,
    'surveyorId': surveyorId,
    'createdAt': createdAt.toIso8601String(),
    'buildings': buildings.map((b) => b.toJson()).toList(),
    'synced': synced,
  };

  factory Project.fromJson(Map<String, dynamic> json) => Project(
    id: json['id'] as String,
    siteRef: json['siteRef'] as String,
    siteAddress: json['siteAddress'] as String,
    surveyorId: json['surveyorId'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    buildings: (json['buildings'] as List)
        .map((b) => Building.fromJson(b as Map<String, dynamic>))
        .toList(),
    synced: json['synced'] as bool? ?? false,
  );

  int get componentCount => buildings.fold(
    0,
    (sum, b) => sum + b.rooms.fold(0, (s, r) => s + r.components.length),
  );
}
