import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/update_bloc.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(
            title: Text('Settings'),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              const ListTile(
                leading: Icon(Icons.language),
                title: Text('Language'),
                subtitle: Text('English'),
                trailing: Icon(Icons.chevron_right),
              ),
              const Divider(),
              BlocBuilder<UpdateBloc, UpdateState>(
                builder: (context, state) {
                  String subtitle = 'Version 0.1.0';
                  if (state is UpdateChecking) {
                    subtitle = 'Checking...';
                  } else if (state is UpdateChecked) {
                    if (state.info.hasUpdate) {
                      subtitle = 'Update available: ${state.info.latestVersion}';
                    } else {
                      subtitle = 'Up to date';
                    }
                  } else if (state is UpdateError) {
                    subtitle = 'Check failed';
                  }

                  return ListTile(
                    leading: const Icon(Icons.system_update),
                    title: const Text('Check for Updates'),
                    subtitle: Text(subtitle),
                    trailing: state is UpdateChecking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.chevron_right),
                    onTap: () {
                      context
                          .read<UpdateBloc>()
                          .add(CheckUpdateRequested());
                    },
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('About ClawSweeper'),
                onTap: () {
                  // Navigate to about page
                },
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
