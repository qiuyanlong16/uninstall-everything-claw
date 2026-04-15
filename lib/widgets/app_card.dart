import 'package:flutter/material.dart';
import '../models/scanned_app.dart';

String _formatSize(int bytes) {
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class AppCard extends StatelessWidget {
  final ScannedApp app;
  final bool selected;
  final void Function(bool) onSelectionChanged;

  const AppCard({
    super.key,
    required this.app,
    required this.selected,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final badge = app.statusBadge;
    final (badgeIcon, badgeText) = _buildBadge(badge);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Checkbox(
              value: selected,
              onChanged: (v) => onSelectionChanged(v ?? false),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        app.name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'v${app.version}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[600]),
                      ),
                      const Spacer(),
                      Text(_formatSize(app.sizeBytes),
                          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    app.installPath,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      badgeIcon,
                      const SizedBox(width: 4),
                      Text(badgeText,
                          style: TextStyle(
                              fontSize: 12,
                              color: badge == StatusBadge.removable
                                  ? Colors.green
                                  : badge == StatusBadge.needsPrivilege
                                      ? Colors.orange
                                      : Colors.red)),
                      if (app.autoStart) ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.play_circle_outline,
                            size: 14, color: Colors.blue),
                        const SizedBox(width: 4),
                        Text('Auto-start',
                            style: TextStyle(fontSize: 12, color: Colors.blue)),
                      ],
                      if (app.pid != null) ...[
                        const SizedBox(width: 12),
                        Text('PID: ${app.pid}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  (Icon, String) _buildBadge(StatusBadge badge) {
    switch (badge) {
      case StatusBadge.removable:
        return (
          const Icon(Icons.check_circle, size: 14, color: Colors.green),
          'Removable',
        );
      case StatusBadge.needsPrivilege:
        return (
          const Icon(Icons.lock_outline, size: 14, color: Colors.orange),
          'Admin required',
        );
      case StatusBadge.running:
        return (
          const Icon(Icons.warning, size: 14, color: Colors.red),
          'Running',
        );
    }
  }
}
