import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/project_controller.dart';
import 'project_screen.dart';

/// Create a new project: site reference/ID and address.
class NewProjectScreen extends StatefulWidget {
  final String surveyorId;
  const NewProjectScreen({super.key, required this.surveyorId});

  @override
  State<NewProjectScreen> createState() => _NewProjectScreenState();
}

class _NewProjectScreenState extends State<NewProjectScreen> {
  final _siteRefController = TextEditingController();
  final _siteAddressController = TextEditingController();
  bool _creating = false;

  bool get _canCreate =>
      _siteRefController.text.trim().isNotEmpty && !_creating;

  Future<void> _create() async {
    setState(() => _creating = true);
    await context.read<ProjectController>().createProject(
          surveyorId: widget.surveyorId,
          siteRef: _siteRefController.text.trim(),
          siteAddress: _siteAddressController.text.trim(),
        );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ProjectScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Project')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Site details',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Surveyor: ${widget.surveyorId}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 20),
          TextField(
            controller: _siteRefController,
            decoration: const InputDecoration(
              labelText: 'Site reference / ID',
              prefixIcon: Icon(Icons.tag_rounded),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _siteAddressController,
            decoration: const InputDecoration(
              labelText: 'Site address',
              prefixIcon: Icon(Icons.place_outlined),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _canCreate ? _create : null,
            child: _creating
                ? const SizedBox(
                    height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Create Project'),
          ),
        ],
      ),
    );
  }
}
