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
import '../theme/app_theme.dart';
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

  bool get _canSave =>
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

  void _clearPhoto(int slot) => setState(() => _photoPaths[slot] = null);

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
    required int step,
    required String label,
    required String? value,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    final done = value != null;
    return ListTile(
      enabled: enabled,
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: done
            ? colors.primary
            : (enabled ? colors.surfaceContainerHighest : colors.surfaceContainerHighest.withValues(alpha: 0.5)),
        child: done
            ? Icon(Icons.check_rounded, size: 16, color: colors.onPrimary)
            : Text('$step',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: enabled ? colors.onSurfaceVariant : colors.onSurfaceVariant.withValues(alpha: 0.4))),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(value ?? 'Not selected'),
      trailing: const Icon(Icons.chevron_right_rounded),
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
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Component' : 'Add Component')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _SectionCard(
            title: 'Photos',
            subtitle: 'Optional - take up to 3 reference photos',
            child: Row(
              children: List.generate(3, (i) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < 2 ? 10 : 0),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _takePhoto(i),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(12),
                                  image: _photoPaths[i] != null
                                      ? DecorationImage(
                                          image: FileImage(File(_photoPaths[i]!)), fit: BoxFit.cover)
                                      : null,
                                ),
                                child: _photoPaths[i] == null
                                    ? Icon(Icons.add_a_photo_rounded, size: 26, color: colors.onSurfaceVariant)
                                    : null,
                              ),
                            ),
                          ),
                          if (_photoPaths[i] != null)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _clearPhoto(i),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          _SectionCard(
            title: 'Component Classification',
            padded: false,
            child: Column(
              children: [
                _levelTile(
                  step: 1,
                  label: 'Group',
                  value: _group,
                  enabled: true,
                  onTap: () => _pick(0, 'Select Group', hierarchy.groups()),
                ),
                _levelTile(
                  step: 2,
                  label: 'System',
                  value: _system,
                  enabled: _group != null,
                  onTap: () => _pick(1, 'Select System', hierarchy.systems(_group!)),
                ),
                _levelTile(
                  step: 3,
                  label: 'Element',
                  value: _element,
                  enabled: _system != null,
                  onTap: () => _pick(2, 'Select Element', hierarchy.elements(_group!, _system!)),
                ),
                _levelTile(
                  step: 4,
                  label: 'Sub-Element',
                  value: _subElement,
                  enabled: _element != null,
                  onTap: () => _pick(
                      3, 'Select Sub-Element', hierarchy.subElements(_group!, _system!, _element!)),
                ),
                _levelTile(
                  step: 5,
                  label: 'Component',
                  value: _component,
                  enabled: _subElement != null,
                  onTap: () => _pick(4, 'Select Component',
                      hierarchy.components(_group!, _system!, _element!, _subElement!)),
                ),
                _levelTile(
                  step: 6,
                  label: 'Sub-Component',
                  value: _subComponent,
                  enabled: _component != null,
                  onTap: () => _pick(5, 'Select Sub-Component',
                      hierarchy.subComponents(_group!, _system!, _element!, _subElement!, _component!)),
                ),
                if (_resolvedEntry != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'RSL ${_resolvedEntry!.rsl} · SFG ${_resolvedEntry!.sfgCode} · Unit ${_resolvedEntry!.unit}',
                        style: TextStyle(fontSize: 12.5, color: colors.onPrimaryContainer),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _SectionCard(
            title: 'Survey Details',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _qtyController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Quantity', prefixIcon: Icon(Icons.tag_rounded)),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 18),
                _ChipLabel('Core / System'),
                const SizedBox(height: 8),
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
                const SizedBox(height: 18),
                _ChipLabel('Condition rating (A best · D worst)'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ConditionRating.values
                      .map((v) => _ColorChoiceChip(
                            label: v.label,
                            color: AppTheme.conditionColor(v),
                            selected: _conditionRating == v,
                            onSelected: () => setState(() => _conditionRating = v),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 18),
                _ChipLabel('Priority (1 urgent · 4 low)'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ConditionPriority.values
                      .map((v) => _ColorChoiceChip(
                            label: v.label,
                            color: AppTheme.priorityColor(v),
                            selected: _conditionPriority == v,
                            onSelected: () => setState(() => _conditionPriority = v),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton(
          onPressed: _canSave ? _save : null,
          child: _saving
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_isEditing ? 'Save Changes' : 'Save Component'),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final bool padded;
  const _SectionCard({required this.title, this.subtitle, required this.child, this.padded = true});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: EdgeInsets.only(
          left: padded ? 16 : 0,
          right: padded ? 16 : 0,
          top: 16,
          bottom: padded ? 16 : 4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: padded ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: TextStyle(fontSize: 12.5, color: colors.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ChipLabel extends StatelessWidget {
  final String text;
  const _ChipLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(
            fontSize: 12.5, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant));
  }
}

class _ColorChoiceChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onSelected;
  const _ColorChoiceChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        color: selected ? Colors.white : color,
      ),
      selectedColor: color,
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: selected ? 0 : 0.4)),
    );
  }
}
