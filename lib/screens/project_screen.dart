import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/building.dart';
import '../services/csv_export_service.dart';
import '../state/project_controller.dart';
import '../widgets/empty_state.dart';
import '../widgets/sync_status_badge.dart';
import 'building_screen.dart';

/// Shows the buildings within the open project. From here the surveyor adds
/// buildings (or marks the location as "External"), and can save/export.
class ProjectScreen extends StatelessWidget {
  const ProjectScreen({super.key});

  Future<void> _addOrEditBuilding(BuildContext context, {Building? existing}) async {
    final controller = context.read<ProjectController>();
    final refController = TextEditingController(text: existing?.reference == 'External' ? '' : existing?.reference);
    bool isExternal = existing?.isExternal ?? false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(existing == null ? 'Add Building' : 'Edit Building'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: refController,
                enabled: !isExternal,
                decoration: const InputDecoration(labelText: 'Building reference'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('External (outside any building)'),
                value: isExternal,
                onChanged: (v) => setState(() => isExternal = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: (isExternal || refController.text.trim().isNotEmpty)
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
      controller.addBuilding(reference: refController.text.trim(), isExternal: isExternal);
    } else {
      controller.updateBuilding(existing,
          reference: refController.text.trim(), isExternal: isExternal);
    }
  }

  Future<void> _confirmDelete(BuildContext context, Building building) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Building?'),
        content: Text(
            '"${building.reference}" and everything recorded inside it (${building.rooms.length} rooms) will be removed.'),
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
      context.read<ProjectController>().deleteBuilding(building);
    }
  }

  Future<void> _export(BuildContext context) async {
    final project = context.read<ProjectController>().project!;
    final exportService = context.read<CsvExportService>();
    if (project.componentCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No components recorded yet')),
      );
      return;
    }
    // iPad requires the share sheet to be anchored to a screen position
    // (it's presented as a popover) - derive one from the tapped button so
    // sharing doesn't silently no-op there.
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;
    await exportService.exportAndShare(project, sharePositionOrigin: origin);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProjectController>(
      builder: (context, controller, _) {
        final project = controller.project!;
        return Scaffold(
          appBar: AppBar(
            title: Text(project.siteRef),
            actions: [
              SyncStatusBadge(synced: project.synced),
              Builder(
                builder: (buttonContext) => IconButton(
                  icon: const Icon(Icons.ios_share_rounded),
                  tooltip: 'Export CSV',
                  onPressed: () => _export(buttonContext),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.save_outlined),
                tooltip: 'Save',
                onPressed: () => controller.saveNow(),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: project.buildings.isEmpty
              ? const EmptyState(
                  icon: Icons.apartment_rounded,
                  message: 'No buildings yet\nAdd one to start surveying',
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 96),
                  itemCount: project.buildings.length,
                  itemBuilder: (context, index) {
                    final Building building = project.buildings[index];
                    final roomCount = building.rooms.length;
                    final componentCount =
                        building.rooms.fold(0, (s, r) => s + r.components.length);
                    final colors = Theme.of(context).colorScheme;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: colors.primaryContainer,
                          child: Icon(
                            building.isExternal ? Icons.park_rounded : Icons.apartment_rounded,
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                        title: Text(building.reference, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('$roomCount ${roomCount == 1 ? 'room' : 'rooms'} · $componentCount components'),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded),
                          onSelected: (value) {
                            if (value == 'edit') {
                              _addOrEditBuilding(context, existing: building);
                            } else if (value == 'delete') {
                              _confirmDelete(context, building);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => BuildingScreen(building: building),
                        )),
                      ),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _addOrEditBuilding(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Building'),
          ),
        );
      },
    );
  }
}
