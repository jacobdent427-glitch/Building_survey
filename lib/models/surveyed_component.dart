import 'condition.dart';

/// A single component recorded against a room: three reference photos, the
/// selected point in the hierarchy database, and the surveyor's own
/// observations (quantity, condition, priority).
class SurveyedComponent {
  final String id;
  List<String> photoPaths;

  String group;
  String system;
  String element;
  String subElement;
  String component;
  String subComponent;

  /// Index of the matched row in the hierarchy database (HierarchyEntry.index),
  /// used to pull RSL/SFG/rate/frequency data back out at export time.
  int hierarchyIndex;

  double quantity;
  CoreSystem coreSystem;
  ConditionRating conditionRating;
  ConditionPriority conditionPriority;
  final DateTime recordedAt;

  SurveyedComponent({
    required this.id,
    required this.photoPaths,
    required this.group,
    required this.system,
    required this.element,
    required this.subElement,
    required this.component,
    required this.subComponent,
    required this.hierarchyIndex,
    required this.quantity,
    required this.coreSystem,
    required this.conditionRating,
    required this.conditionPriority,
    required this.recordedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'photoPaths': photoPaths,
        'group': group,
        'system': system,
        'element': element,
        'subElement': subElement,
        'component': component,
        'subComponent': subComponent,
        'hierarchyIndex': hierarchyIndex,
        'quantity': quantity,
        'coreSystem': coreSystem.label,
        'conditionRating': conditionRating.label,
        'conditionPriority': conditionPriority.label,
        'recordedAt': recordedAt.toIso8601String(),
      };

  factory SurveyedComponent.fromJson(Map<String, dynamic> json) => SurveyedComponent(
        id: json['id'] as String,
        photoPaths: List<String>.from(json['photoPaths'] as List),
        group: json['group'] as String,
        system: json['system'] as String,
        element: json['element'] as String,
        subElement: json['subElement'] as String,
        component: json['component'] as String,
        subComponent: json['subComponent'] as String,
        hierarchyIndex: json['hierarchyIndex'] as int,
        quantity: (json['quantity'] as num).toDouble(),
        coreSystem: CoreSystem.fromLabel(json['coreSystem'] as String),
        conditionRating: ConditionRating.fromLabel(json['conditionRating'] as String),
        conditionPriority: ConditionPriority.fromLabel(json['conditionPriority'] as String),
        recordedAt: DateTime.parse(json['recordedAt'] as String),
      );
}
