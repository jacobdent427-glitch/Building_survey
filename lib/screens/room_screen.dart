import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/building.dart';
import '../models/room.dart';
import '../models/surveyed_component.dart';
import '../state/project_controller.dart';
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
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ComponentCaptureScreen(room: widget.room),
    ));
    setState(() {}); // refresh the list on return
  }

  Future<void> _editComponent(SurveyedComponent component) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ComponentCaptureScreen(room: widget.room, existing: component),
    ));
    setState(() {});
  }

  Future<void> _confirmDelete(SurveyedComponent component) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Component?'),
        content: Text(
            'This removes "${component.subComponent.isNotEmpty ? component.subComponent : component.component}" from this room.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
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
          ? const Center(child: Text('No components recorded yet - add one below'))
          : ListView.builder(
              itemCount: components.length,
              itemBuilder: (context, index) {
                final SurveyedComponent c = components[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.construction),
                    title: Text(c.subComponent.isNotEmpty ? c.subComponent : c.component),
                    subtitle: Text(
                      '${c.group} > ${c.system} > ${c.element}\n'
                      'Qty ${c.quantity} · ${c.coreSystem.label} · '
                      'Rating ${c.conditionRating.label} · Priority ${c.conditionPriority.label}',
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editComponent(c);
                        } else if (value == 'delete') {
                          _confirmDelete(c);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addComponent,
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Add Component'),
      ),
    );
  }
}
