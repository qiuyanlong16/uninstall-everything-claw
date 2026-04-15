import 'package:flutter/material.dart';

class PrivilegeBanner extends StatelessWidget {
  final int selectedCount;
  final int privilegeCount;

  const PrivilegeBanner({
    super.key,
    required this.selectedCount,
    required this.privilegeCount,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedCount == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Text('Selected: $selectedCount item(s)'),
          if (privilegeCount > 0) ...[
            const SizedBox(width: 16),
            const Icon(Icons.lock_outline, size: 18, color: Colors.orange),
            const SizedBox(width: 4),
            Text(
              '$privilegeCount require admin',
              style: const TextStyle(color: Colors.orange),
            ),
          ],
        ],
      ),
    );
  }
}
