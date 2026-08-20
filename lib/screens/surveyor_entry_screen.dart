import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project.dart';
import '../services/local_project_store.dart';
import '../state/project_controller.dart';
import 'new_project_screen.dart';
import 'project_screen.dart';

/// First screen: the surveyor identifies themselves, then either opens an
/// existing project (saved on this device) or starts a new one.
class SurveyorEntryScreen extends StatefulWidget {
  const SurveyorEntryScreen({super.key});

  @override
  State<SurveyorEntryScreen> createState() => _SurveyorEntryScreenState();
}

class _SurveyorEntryScreenState extends State<SurveyorEntryScreen> {
  final _surveyorIdController = TextEditingController();
  List<Project> _existingProjects = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    final store = context.read<LocalProjectStore>();
    final projects = await store.listAll();
    setState(() {
      _existingProjects = projects;
      _loading = false;
    });
  }

  bool get _canContinue => _surveyorIdController.text.trim().isNotEmpty;

  void _startNewProject() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => NewProjectScreen(surveyorId: _surveyorIdController.text.trim()),
    ));
  }

  Future<void> _openProject(Project project) async {
    await context.read<ProjectController>().openProject(project);
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProjectScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Building Survey')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Surveyor ID', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _surveyorIdController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'e.g. JD-102',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _canContinue ? _startNewProject : null,
              icon: const Icon(Icons.add),
              label: const Text('New Project'),
            ),
            const SizedBox(height: 24),
            Text('Existing projects on this device',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _existingProjects.isEmpty
                      ? const Center(child: Text('No saved projects yet'))
                      : ListView.builder(
                          itemCount: _existingProjects.length,
                          itemBuilder: (context, index) {
                            final project = _existingProjects[index];
                            return Card(
                              child: ListTile(
                                title: Text(project.siteRef),
                                subtitle: Text(
                                    '${project.siteAddress}\n${project.componentCount} components'),
                                isThreeLine: true,
                                trailing: Icon(
                                  project.synced ? Icons.cloud_done : Icons.cloud_off,
                                  color: project.synced ? Colors.green : Colors.grey,
                                ),
                                enabled: _canContinue,
                                onTap: _canContinue ? () => _openProject(project) : null,
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
