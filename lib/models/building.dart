import 'room.dart';

/// A building within a project, or the special "External" building used for
/// components surveyed outside any building.
class Building {
  final String id;
  String reference;
  bool isExternal;
  final List<Room> rooms;

  Building({
    required this.id,
    required this.reference,
    this.isExternal = false,
    List<Room>? rooms,
  }) : rooms = rooms ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'reference': reference,
        'isExternal': isExternal,
        'rooms': rooms.map((r) => r.toJson()).toList(),
      };

  factory Building.fromJson(Map<String, dynamic> json) => Building(
        id: json['id'] as String,
        reference: json['reference'] as String,
        isExternal: json['isExternal'] as bool? ?? false,
        rooms: (json['rooms'] as List)
            .map((r) => Room.fromJson(r as Map<String, dynamic>))
            .toList(),
      );
}
