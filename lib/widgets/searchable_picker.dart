import 'package:flutter/material.dart';

/// Opens a full-height searchable list and returns the option the user
/// picked, or null if they dismissed it. Used for every level of the
/// hierarchy cascade, since several levels have hundreds of options.
Future<String?> showSearchablePicker(
  BuildContext context, {
  required String title,
  required List<String> options,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _SearchablePickerSheet(title: title, options: options),
  );
}

class _SearchablePickerSheet extends StatefulWidget {
  final String title;
  final List<String> options;
  const _SearchablePickerSheet({required this.title, required this.options});

  @override
  State<_SearchablePickerSheet> createState() => _SearchablePickerSheetState();
}

class _SearchablePickerSheetState extends State<_SearchablePickerSheet> {
  late List<String> _filtered = widget.options;
  final _searchController = TextEditingController();

  void _onSearch(String query) {
    setState(() {
      _filtered = query.isEmpty
          ? widget.options
          : widget.options
              .where((o) => o.toLowerCase().contains(query.toLowerCase()))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Text(widget.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Search...',
                ),
                onChanged: _onSearch,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _filtered.isEmpty
                    ? Center(
                        child: Text('No matches', style: TextStyle(color: colors.onSurfaceVariant)))
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: _filtered.length,
                        separatorBuilder: (_, _) => Divider(height: 1, color: colors.outlineVariant.withValues(alpha: 0.3)),
                        itemBuilder: (context, index) {
                          final option = _filtered[index];
                          return ListTile(
                            title: Text(option),
                            onTap: () => Navigator.pop(context, option),
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
}
