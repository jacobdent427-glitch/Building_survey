import 'surveyed_component.dart';

/// A room (or external area) within a building, holding the components
/// surveyed inside it.
class Room {
  final String id;
  String reference;
  String floor;
  String what3words;
  final List<SurveyedComponent> components;

  Room({
    required this.id,
    required this.reference,
    this.floor = '',
    this.what3words = '',
    List<SurveyedComponent>? components,
  }) : components = components ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'reference': reference,
        'floor': floor,
        'what3words': what3words,
        'components': components.map((c) => c.toJson()).toList(),
      };

  factory Room.fromJson(Map<String, dynamic> json) => Room(
        id: json['id'] as String,
        reference: json['reference'] as String,
        floor: json['floor'] as String? ?? '',
        what3words: json['what3words'] as String? ?? '',
        components: (json['components'] as List)
            .map((c) => SurveyedComponent.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}
