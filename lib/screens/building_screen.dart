import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/building.dart';
import '../models/room.dart';
import '../services/location_service.dart';
import '../services/what3words_service.dart';
import '../state/project_controller.dart';
import '../widgets/empty_state.dart';
import 'room_screen.dart';

/// Shows the rooms within a building. The surveyor adds a room reference,
/// floor, and, optionally, a what3words location for it.
class BuildingScreen extends StatelessWidget {
  final Building building;
  const BuildingScreen({super.key, required this.building});

  Future<void> _addOrEditRoom(BuildContext context, {Room? existing}) async {
    final controller = context.read<ProjectController>();
    final w3wService = context.read<What3WordsService>();
    final locationService = context.read<LocationService>();
    final refController = TextEditingController(text: existing?.reference);
    final floorController = TextEditingController(text: existing?.floor);
    final w3wController = TextEditingController(text: existing?.what3words);
    List<String> suggestions = [];
    bool locating = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          Future<void> useCurrentLocation() async {
            setState(() {
              locating = true;
              suggestions = [];
            });
            try {
              final position = await locationService.currentPosition();
              final words = await w3wService.wordsForCoordinates(
                position.latitude,
                position.longitude,
              );
              w3wController.text = words;
            } on LocationException catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(e.message)));
              }
            } on What3WordsException catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(e.message)));
              }
            } finally {
              if (context.mounted) setState(() => locating = false);
            }
          }

          return AlertDialog(
            title: Text(existing == null ? 'Add Room' : 'Edit Room'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: refController,
                    decoration: const InputDecoration(
                      labelText: 'Room reference',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: floorController,
                    decoration: const InputDecoration(
                      labelText: 'Floor (optional)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: w3wController,
                    decoration: InputDecoration(
                      labelText: 'what3words (optional)',
                      hintText: 'e.g. filled.count.soap',
                      suffixIcon: locating
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.my_location_rounded),
                              tooltip: 'Use my current location',
                              onPressed: useCurrentLocation,
                            ),
                    ),
                    onChanged: (value) async {
                      final s = await w3wService.suggest(value);
                      setState(() => suggestions = s);
                    },
                  ),
                  if (suggestions.isNotEmpty)
                    ...suggestions.map(
                      (s) => ListTile(
                        dense: true,
                        title: Text(s),
                        onTap: () {
                          w3wController.text = s;
                          setState(() => suggestions = []);
                        },
                      ),
                    ),
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
          );
        },
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
          '"${room.reference}" and its ${room.components.length} recorded components will be removed.',
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
              ? const EmptyState(
                  icon: Icons.meeting_room_rounded,
                  message:
                      'No rooms yet\nAdd one to start recording components',
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 96),
                  itemCount: building.rooms.length,
                  itemBuilder: (context, index) {
                    final Room room = building.rooms[index];
                    final subtitleParts = [
                      if (room.floor.isNotEmpty) 'Floor ${room.floor}',
                      if (room.what3words.isNotEmpty) room.what3words,
                      '${room.components.length} components',
                    ];
                    final colors = Theme.of(context).colorScheme;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: colors.secondaryContainer,
                          child: Icon(
                            Icons.meeting_room_rounded,
                            color: colors.onSecondaryContainer,
                          ),
                        ),
                        title: Text(
                          room.reference,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(subtitleParts.join(' · ')),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded),
                          onSelected: (value) {
                            if (value == 'edit') {
                              _addOrEditRoom(context, existing: room);
                            } else if (value == 'delete') {
                              _confirmDelete(context, room);
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
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                RoomScreen(building: building, room: room),
                          ),
                        ),
                      ),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _addOrEditRoom(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Room'),
          ),
        );
      },
    );
  }
}
