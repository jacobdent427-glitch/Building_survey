import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/condition.dart';
import '../models/hierarchy_entry.dart';
import '../models/room.dart';
import '../models/surveyed_component.dart';
import '../services/hierarchy_repository.dart';
import '../services/photo_service.dart';
import '../state/project_controller.dart';
import '../widgets/searchable_picker.dart';

/// The full capture flow for one component: three reference photos, then a
/// cascading Group -> System -> Element -> Sub-Element -> Component ->
/// Sub-Component search against the hierarchy database, then the
/// surveyor's own quantity/condition observations. Also used to edit a
/// previously-saved component when [existing] is supplied.
class ComponentCaptureScreen extends StatefulWidget {
  final Room room;
  final SurveyedComponent? existing;
  const ComponentCaptureScreen({super.key, required this.room, this.existing});

  @override
  State<ComponentCaptureScreen> createState() => _ComponentCaptureScreenState();
}

class _ComponentCaptureScreenState extends State<ComponentCaptureScreen> {
  late List<String?> _photoPaths;

  String? _group;
  String? _system;
  String? _element;
  String? _subElement;
  String? _component;
  String? _subComponent;
  HierarchyEntry? _resolvedEntry;

  late final TextEditingController _qtyController;
  CoreSystem? _coreSystem;
  ConditionRating? _conditionRating;
  ConditionPriority? _conditionPriority;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _photoPaths = existing != null
        ? List<String?>.from(existing.photoPaths)
        : [null, null, null];
    while (_photoPaths.length < 3) {
      _photoPaths.add(null);
    }
    _qtyController = TextEditingController(text: (existing?.quantity ?? 1).toString());
    _coreSystem = existing?.coreSystem;
    _conditionRating = existing?.conditionRating;
    _conditionPriority = existing?.conditionPriority;

    if (existing != null) {
      _group = existing.group;
      _system = existing.system;
      _element = existing.element;
      _subElement = existing.subElement;
      _component = existing.component;
      _subComponent = existing.subComponent;
      try {
        _resolvedEntry = context.read<HierarchyRepository>().entryByIndex(existing.hierarchyIndex);
      } catch (_) {
        _resolvedEntry = null;
      }
    }
  }

  bool get _photosComplete => _photoPaths.every((p) => p != null);

  bool get _canSave =>
      _photosComplete &&
      _resolvedEntry != null &&
      double.tryParse(_qtyController.text) != null &&
      _coreSystem != null &&
      _conditionRating != null &&
      _conditionPriority != null &&
      !_saving;

  Future<void> _takePhoto(int slot) async {
    final photoService = context.read<PhotoService>();
    final projectId = context.read<ProjectController>().project!.id;
    final path = await photoService.captureForProject(projectId);
    if (path != null) setState(() => _photoPaths[slot] = path);
  }

  void _resetBelow(int levelIndex) {
    // 0=group,1=system,2=element,3=subElement,4=component,5=subComponent
    if (levelIndex <= 0) _system = null;
    if (levelIndex <= 1) _element = null;
    if (levelIndex <= 2) _subElement = null;
    if (levelIndex <= 3) _component = null;
    if (levelIndex <= 4) _subComponent = null;
    _resolvedEntry = null;
  }

  Future<void> _pick(int levelIndex, String title, List<String> options) async {
    final selected = await showSearchablePicker(context, title: title, options: options);
    if (selected == null) return;
    setState(() {
      _resetBelow(levelIndex);
      switch (levelIndex) {
        case 0:
          _group = selected;
          break;
        case 1:
          _system = selected;
          break;
        case 2:
          _element = selected;
          break;
        case 3:
          _subElement = selected;
          break;
        case 4:
          _component = selected;
          break;
        case 5:
          _subComponent = selected;
          break;
      }
      _tryResolveEntry();
    });
  }

  Future<void> _tryResolveEntry() async {
    if (_group == null ||
        _system == null ||
        _element == null ||
        _subElement == null ||
        _component == null ||
        _subComponent == null) {
      return;
    }
    final hierarchy = context.read<HierarchyRepository>();
    final matches = hierarchy.matchingEntries(
        _group!, _system!, _element!, _subElement!, _component!, _subComponent!);

    if (matches.length == 1) {
      setState(() => _resolvedEntry = matches.first);
    } else if (matches.length > 1) {
      final entry = await _disambiguate(matches);
      if (entry != null) setState(() => _resolvedEntry = entry);
    }
  }

  Future<HierarchyEntry?> _disambiguate(List<HierarchyEntry> matches) {
    return showModalBottomSheet<HierarchyEntry>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('This item has more than one database entry - pick the matching one:',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: matches.length,
                  itemBuilder: (context, index) {
                    final e = matches[index];
                    return ListTile(
                      title: Text('${e.subComponent} (${e.unit})'),
                      subtitle: Text('SFG ${e.sfgCode} · RSL ${e.rsl} · Rate ${e.rate}'),
                      onTap: () => Navigator.pop(context, e),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _levelTile({
    required String label,
    required String? value,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return ListTile(
      enabled: enabled,
      title: Text(label),
      subtitle: Text(value ?? 'Not selected'),
      trailing: const Icon(Icons.chevron_right),
      onTap: enabled ? onTap : null,
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final controller = context.read<ProjectController>();
    final existing = widget.existing;
    if (existing == null) {
      controller.addComponent(
        widget.room,
        photoPaths: _photoPaths.whereType<String>().toList(),
        group: _group!,
        system: _system!,
        element: _element!,
        subElement: _subElement!,
        component: _component!,
        subComponent: _subComponent!,
        hierarchyIndex: _resolvedEntry!.index,
        quantity: double.parse(_qtyController.text),
        coreSystem: _coreSystem!,
        conditionRating: _conditionRating!,
        conditionPriority: _conditionPriority!,
      );
    } else {
      controller.updateComponent(
        existing,
        photoPaths: _photoPaths.whereType<String>().toList(),
        group: _group!,
        system: _system!,
        element: _element!,
        subElement: _subElement!,
        component: _component!,
        subComponent: _subComponent!,
        hierarchyIndex: _resolvedEntry!.index,
        quantity: double.parse(_qtyController.text),
        coreSystem: _coreSystem!,
        conditionRating: _conditionRating!,
        conditionPriority: _conditionPriority!,
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final hierarchy = context.read<HierarchyRepository>();

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Component' : 'Add Component')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Photos', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: List.generate(3, (i) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: InkWell(
                      onTap: () => _takePhoto(i),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                          image: _photoPaths[i] != null
                              ? DecorationImage(
                                  image: FileImage(File(_photoPaths[i]!)), fit: BoxFit.cover)
                              : null,
                        ),
                        child: _photoPaths[i] == null
                            ? const Icon(Icons.camera_alt, size: 32)
                            : null,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const Divider(height: 32),
          Text('Component Classification', style: Theme.of(context).textTheme.titleMedium),
          _levelTile(
            label: 'Group',
            value: _group,
            enabled: true,
            onTap: () => _pick(0, 'Select Group', hierarchy.groups()),
          ),
          _levelTile(
            label: 'System',
            value: _system,
            enabled: _group != null,
            onTap: () => _pick(1, 'Select System', hierarchy.systems(_group!)),
          ),
          _levelTile(
            label: 'Element',
            value: _element,
            enabled: _system != null,
            onTap: () => _pick(2, 'Select Element', hierarchy.elements(_group!, _system!)),
          ),
          _levelTile(
            label: 'Sub-Element',
            value: _subElement,
            enabled: _element != null,
            onTap: () => _pick(
                3, 'Select Sub-Element', hierarchy.subElements(_group!, _system!, _element!)),
          ),
          _levelTile(
            label: 'Component',
            value: _component,
            enabled: _subElement != null,
            onTap: () => _pick(4, 'Select Component',
                hierarchy.components(_group!, _system!, _element!, _subElement!)),
          ),
          _levelTile(
            label: 'Sub-Component',
            value: _subComponent,
            enabled: _component != null,
            onTap: () => _pick(5, 'Select Sub-Component',
                hierarchy.subComponents(_group!, _system!, _element!, _subElement!, _component!)),
          ),
          if (_resolvedEntry != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'RSL: ${_resolvedEntry!.rsl}   SFG: ${_resolvedEntry!.sfgCode}   Unit: ${_resolvedEntry!.unit}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const Divider(height: 32),
          Text('Survey Details', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _qtyController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Text('Core / System'),
          Wrap(
            spacing: 8,
            children: CoreSystem.values
                .map((v) => ChoiceChip(
                      label: Text(v.label),
                      selected: _coreSystem == v,
                      onSelected: (_) => setState(() => _coreSystem = v),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          const Text('Condition rating (A best - D worst)'),
          Wrap(
            spacing: 8,
            children: ConditionRating.values
                .map((v) => ChoiceChip(
                      label: Text(v.label),
                      selected: _conditionRating == v,
                      onSelected: (_) => setState(() => _conditionRating = v),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          const Text('Priority (1 urgent - 4 low)'),
          Wrap(
            spacing: 8,
            children: ConditionPriority.values
                .map((v) => ChoiceChip(
                      label: Text(v.label),
                      selected: _conditionPriority == v,
                      onSelected: (_) => setState(() => _conditionPriority = v),
                    ))
                .toList(),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _canSave ? _save : null,
            child: Text(_isEditing ? 'Save Changes' : 'Save Component'),
          ),
        ],
      ),
    );
  }
}
