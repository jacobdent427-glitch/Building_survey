import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/building.dart';
import '../services/csv_export_service.dart';
import '../state/project_controller.dart';
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
              SwitchListTile(
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
    await exportService.exportAndShare(project);
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
              Icon(project.synced ? Icons.cloud_done : Icons.cloud_off),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.ios_share),
                tooltip: 'Export CSV',
                onPressed: () => _export(context),
              ),
              IconButton(
                icon: const Icon(Icons.save),
                tooltip: 'Save',
                onPressed: () => controller.saveNow(),
              ),
            ],
          ),
          body: project.buildings.isEmpty
              ? const Center(child: Text('No buildings yet - add one below'))
              : ListView.builder(
                  itemCount: project.buildings.length,
                  itemBuilder: (context, index) {
                    final Building building = project.buildings[index];
                    final roomCount = building.rooms.length;
                    final componentCount =
                        building.rooms.fold(0, (s, r) => s + r.components.length);
                    return Card(
                      child: ListTile(
                        leading: Icon(building.isExternal ? Icons.park : Icons.apartment),
                        title: Text(building.reference),
                        subtitle: Text('$roomCount rooms, $componentCount components'),
                        trailing: PopupMenuButton<String>(
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
            icon: const Icon(Icons.add),
            label: const Text('Add Building'),
          ),
        );
      },
    );
  }
}
