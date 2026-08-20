import 'package:flutter/material.dart';

/// Small pill in the app bar showing whether a project's latest changes
/// have reached the cloud yet.
class SyncStatusBadge extends StatelessWidget {
  final bool synced;
  const SyncStatusBadge({super.key, required this.synced});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = synced ? const Color(0xFF2E7D32) : colors.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Tooltip(
        message: synced ? 'Synced to cloud' : 'Not synced yet',
        child: Icon(
          synced ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
          color: color,
          size: 22,
        ),
      ),
    );
  }
}
