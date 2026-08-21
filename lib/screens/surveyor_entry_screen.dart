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

  Future<void> _startNewProject() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            NewProjectScreen(surveyorId: _surveyorIdController.text.trim()),
      ),
    );
    // The project list on this screen was only loaded once, in initState -
    // refresh it now that we're back, or a newly-created project stays
    // invisible here until the app is force-closed and reopened.
    if (mounted) await _loadProjects();
  }

  Future<void> _openProject(Project project) async {
    await context.read<ProjectController>().openProject(project);
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ProjectScreen()));
    if (mounted) await _loadProjects();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          children: [
            Text(
              'Building Survey',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Sign in with your surveyor ID to begin',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _surveyorIdController,
              decoration: const InputDecoration(
                labelText: 'Surveyor ID',
                hintText: 'e.g. JD-102',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _canContinue ? _startNewProject : null,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Project'),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Text(
                  'Saved projects',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                if (_existingProjects.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colors.secondaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_existingProjects.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colors.onSecondaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_existingProjects.isEmpty)
              _EmptyProjectsHint(colors: colors)
            else
              // Opening a saved project doesn't need a surveyor ID typed in -
              // the project already has one from when it was created.
              ..._existingProjects.map(
                (project) =>
                    _ProjectTile(project: project, onTap: () => _openProject(project)),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyProjectsHint extends StatelessWidget {
  final ColorScheme colors;
  const _EmptyProjectsHint({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.folder_open_rounded,
            size: 32,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            'No saved projects yet',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ProjectTile extends StatelessWidget {
  final Project project;
  final VoidCallback onTap;
  const _ProjectTile({required this.project, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: colors.primaryContainer,
          child: Icon(
            Icons.apartment_rounded,
            color: colors.onPrimaryContainer,
          ),
        ),
        title: Text(
          project.siteRef,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${project.siteAddress}\n${project.componentCount} components recorded',
        ),
        isThreeLine: true,
        trailing: Icon(
          project.synced ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
          color: project.synced
              ? const Color(0xFF2E7D32)
              : colors.onSurfaceVariant,
        ),
      ),
    );
  }
}
