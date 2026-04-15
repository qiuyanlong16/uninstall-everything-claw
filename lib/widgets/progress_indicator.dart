import 'package:flutter/material.dart';

String _statusLabel(String status) {
  switch (status) {
    case 'stopping':
      return 'Stopping process...';
    case 'elevating':
      return 'Elevating privileges...';
    case 'uninstalling':
      return 'Uninstalling...';
    case 'cleaningresidue':
      return 'Cleaning residue...';
    case 'done':
      return 'Done';
    case 'failed':
      return 'Failed';
    default:
      return status;
  }
}

class AppProgressIndicator extends StatelessWidget {
  final String appName;
  final String status;
  final bool isComplete;

  const AppProgressIndicator({
    super.key,
    required this.appName,
    required this.status,
    this.isComplete = false,
  });

  @override
  Widget build(BuildContext context) {
    final isFailed = status == 'failed';
    final isDone = status == 'done';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (!isComplete)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (isDone)
            const Icon(Icons.check_circle, size: 16, color: Colors.green)
          else if (isFailed)
            const Icon(Icons.error, size: 16, color: Colors.red),
          const SizedBox(width: 12),
          Text(appName, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Text(
            _statusLabel(status),
            style: TextStyle(
              color: isFailed
                  ? Colors.red
                  : isDone
                      ? Colors.green
                      : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
