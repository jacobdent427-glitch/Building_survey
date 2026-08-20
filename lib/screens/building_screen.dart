import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/building.dart';
import '../models/room.dart';
import '../services/what3words_service.dart';
import '../state/project_controller.dart';
import 'room_screen.dart';

/// Shows the rooms within a building. The surveyor adds a room reference,
/// floor, and, optionally, a what3words location for it.
class BuildingScreen extends StatelessWidget {
  final Building building;
  const BuildingScreen({super.key, required this.building});

  Future<void> _addOrEditRoom(BuildContext context, {Room? existing}) async {
    final controller = context.read<ProjectController>();
    final w3wService = context.read<What3WordsService>();
    final refController = TextEditingController(text: existing?.reference);
    final floorController = TextEditingController(text: existing?.floor);
    final w3wController = TextEditingController(text: existing?.what3words);
    List<String> suggestions = [];

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(existing == null ? 'Add Room' : 'Edit Room'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: refController,
                  decoration: const InputDecoration(labelText: 'Room reference'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: floorController,
                  decoration: const InputDecoration(labelText: 'Floor (optional)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: w3wController,
                  decoration: const InputDecoration(
                    labelText: 'what3words (optional)',
                    hintText: 'e.g. filled.count.soap',
                  ),
                  onChanged: (value) async {
                    final s = await w3wService.suggest(value);
                    setState(() => suggestions = s);
                  },
                ),
                if (suggestions.isNotEmpty)
                  ...suggestions.map((s) => ListTile(
                        dense: true,
                        title: Text(s),
                        onTap: () {
                          w3wController.text = s;
                          setState(() => suggestions = []);
                        },
                      )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: refController.text.trim().isNotEmpty
                  ? () => Navigator.pop(context, true)
                  : null,
              child: Text(existing == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;
    if (existing == null) {
      controller.addRoom(
        building,
        reference: refController.text.trim(),
        floor: floorController.text.trim(),
        what3words: w3wController.text.trim(),
      );
    } else {
      controller.updateRoom(
        existing,
        reference: refController.text.trim(),
        floor: floorController.text.trim(),
        what3words: w3wController.text.trim(),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, Room room) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Room?'),
        content: Text(
            '"${room.reference}" and its ${room.components.length} recorded components will be removed.'),
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
    if (confirmed == true && context.mounted) {
      context.read<ProjectController>().deleteRoom(building, room);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProjectController>(
      builder: (context, controller, _) {
        return Scaffold(
          appBar: AppBar(title: Text(building.reference)),
          body: building.rooms.isEmpty
              ? const Center(child: Text('No rooms yet - add one below'))
              : ListView.builder(
                  itemCount: building.rooms.length,
                  itemBuilder: (context, index) {
                    final Room room = building.rooms[index];
                    final subtitleParts = [
                      if (room.floor.isNotEmpty) 'Floor ${room.floor}',
                      if (room.what3words.isNotEmpty) room.what3words,
                      '${room.components.length} components',
                    ];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.meeting_room),
                        title: Text(room.reference),
                        subtitle: Text(subtitleParts.join(' · ')),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _addOrEditRoom(context, existing: room);
                            } else if (value == 'delete') {
                              _confirmDelete(context, room);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => RoomScreen(building: building, room: room),
                        )),
                      ),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _addOrEditRoom(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Room'),
          ),
        );
      },
    );
  }
}
