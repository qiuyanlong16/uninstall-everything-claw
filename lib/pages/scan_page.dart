import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/scanner_bloc.dart';
import '../bloc/uninstall_bloc.dart';
import '../models/scanned_app.dart';
import '../widgets/app_card.dart';
import '../widgets/privilege_banner.dart';
import 'uninstall_page.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage>
    with SingleTickerProviderStateMixin {
  final Set<String> _selectedIds = {};
  late TabController _tabController;
  final List<Tab> _tabs = const [
    Tab(text: 'All'),
    Tab(text: 'Claw'),
    Tab(text: 'Hermes'),
    Tab(text: 'Other'),
  ];

  AppFamily _familyForTab(int index) {
    switch (index) {
      case 0:
        return AppFamily.claw;
      case 1:
        return AppFamily.claw;
      case 2:
        return AppFamily.hermes;
      case 3:
        return AppFamily.other;
      default:
        return AppFamily.other;
    }
  }

  bool _shouldShowApp(ScannedApp app, int tabIndex) {
    if (tabIndex == 0) return true;
    return app.family == _familyForTab(tabIndex);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<UninstallBloc, UninstallState>(
      listener: (context, uninstallState) {
        if (uninstallState is UninstallCompleted) {
          context.read<ScannerBloc>().add(ScanRequested());
          setState(() => _selectedIds.clear());
        }
      },
      builder: (context, _) {
        return BlocBuilder<ScannerBloc, ScannerState>(
          builder: (context, state) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text(
                        'AI Agent Scanner',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: state is ScannerLoading
                            ? null
                            : () => context
                                .read<ScannerBloc>()
                                .add(ScanRequested()),
                        icon: state is ScannerLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.search),
                        label: Text(state is ScannerLoading
                            ? 'Scanning...'
                            : 'Scan'),
                      ),
                    ],
                  ),
                ),
                if (state is ScannerLoaded && state.apps.isNotEmpty)
                  TabBar(
                    controller: _tabController,
                    tabs: _tabs,
                    onTap: (_) => setState(() {}),
                  ),
                Expanded(
                  child: _buildBody(state),
                ),
                if (state is ScannerLoaded)
                  Column(
                    children: [
                      PrivilegeBanner(
                        selectedCount: _selectedIds.length,
                        privilegeCount: state.apps
                            .where((a) =>
                                _selectedIds.contains(a.id) &&
                                a.requiresPrivilege)
                            .length,
                      ),
                      if (_selectedIds.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                context
                                    .read<UninstallBloc>()
                                    .add(UninstallRequested(
                                        _selectedIds.toList()));
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const UninstallPage()),
                                );
                              },
                              child: Text('Uninstall ${_selectedIds.length} item(s)'),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBody(ScannerState state) {
    if (state is ScannerInitial) {
      return const Center(child: Text('Press Scan to find AI agents'));
    }
    if (state is ScannerLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is ScannerError) {
      return Center(child: Text('Error: ${state.message}'));
    }
    if (state is ScannerLoaded) {
      final filtered = state.apps
          .where((a) => _shouldShowApp(a, _tabController.index))
          .toList();
      if (filtered.isEmpty) {
        return const Center(child: Text('No agents found in this category'));
      }
      return ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final app = filtered[index];
          return AppCard(
            app: app,
            selected: _selectedIds.contains(app.id),
            onSelectionChanged: (selected) {
              setState(() {
                if (selected) {
                  _selectedIds.add(app.id);
                } else {
                  _selectedIds.remove(app.id);
                }
              });
            },
          );
        },
      );
    }
    return const SizedBox.shrink();
  }
}
