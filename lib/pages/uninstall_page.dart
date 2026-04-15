import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/uninstall_bloc.dart';
import '../widgets/progress_indicator.dart';

class UninstallPage extends StatelessWidget {
  const UninstallPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Uninstalling')),
      body: BlocBuilder<UninstallBloc, UninstallState>(
        builder: (context, state) {
          if (state is UninstallInitial) {
            return const Center(child: Text('Starting uninstall...'));
          }
          if (state is UninstallProgress) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppProgressIndicator(
                    appName: state.appId,
                    status: state.status,
                  ),
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(),
                ],
              ),
            );
          }
          if (state is UninstallCompleted) {
            final successCount = state.results.values.where((v) => v).length;
            final failCount = state.results.values.where((v) => !v).length;
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    failCount == 0 ? Icons.check_circle : Icons.warning,
                    size: 64,
                    color: failCount == 0 ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$successCount removed, $failCount failed',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back to Scan'),
                  ),
                ],
              ),
            );
          }
          if (state is UninstallFailed) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Failed: ${state.message}'),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back to Scan'),
                  ),
                ],
              ),
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
