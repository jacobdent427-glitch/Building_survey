import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/building.dart';
import '../models/room.dart';
import '../models/surveyed_component.dart';
import '../state/project_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import 'component_capture_screen.dart';

/// Shows the components recorded in this room, and lets the surveyor keep
/// adding more without leaving the room.
class RoomScreen extends StatefulWidget {
  final Building building;
  final Room room;
  const RoomScreen({super.key, required this.building, required this.room});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  Future<void> _addComponent() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ComponentCaptureScreen(room: widget.room),
      ),
    );
    setState(() {}); // refresh the list on return
  }

  Future<void> _editComponent(SurveyedComponent component) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ComponentCaptureScreen(room: widget.room, existing: component),
      ),
    );
    setState(() {});
  }

  Future<void> _confirmDelete(SurveyedComponent component) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Component?'),
        content: Text(
          'This removes "${component.subComponent.isNotEmpty ? component.subComponent : component.component}" from this room.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      context.read<ProjectController>().deleteComponent(widget.room, component);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final components = widget.room.components;
    return Scaffold(
      appBar: AppBar(title: Text(widget.room.reference)),
      body: components.isEmpty
          ? const EmptyState(
              icon: Icons.construction_rounded,
              message: 'No components recorded yet\nTake a photo and search the database to add one',
            )
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 96),
              itemCount: components.length,
              itemBuilder: (context, index) {
                final SurveyedComponent c = components[index];
                final ratingColor = AppTheme.conditionColor(c.conditionRating);
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: BoxDecoration(
                            color: ratingColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            c.conditionRating.label,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: ratingColor,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.subComponent.isNotEmpty
                                    ? c.subComponent
                                    : c.component,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${c.group} › ${c.system} › ${c.element}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _Badge(text: 'Qty ${c.quantity}'),
                                  _Badge(text: c.coreSystem.label),
                                  _Badge(
                                    text:
                                        'Priority ${c.conditionPriority.label}',
                                    color: AppTheme.priorityColor(
                                      c.conditionPriority,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded),
                          onSelected: (value) {
                            if (value == 'edit') {
                              _editComponent(c);
                            } else if (value == 'delete') {
                              _confirmDelete(c);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addComponent,
        icon: const Icon(Icons.add_a_photo_rounded),
        label: const Text('Add Component'),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color? color;
  const _Badge({required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final c = color ?? colors.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c),
      ),
    );
  }
}
