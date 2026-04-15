import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'bloc/scanner_bloc.dart';
import 'bloc/uninstall_bloc.dart';
import 'bloc/update_bloc.dart';
import 'core/update/updater.dart';
import 'pages/scan_page.dart';
import 'pages/settings_page.dart';
import 'pages/about_page.dart';

void main() {
  runApp(const ClawSweeperApp());
}

class ClawSweeperApp extends StatelessWidget {
  const ClawSweeperApp({super.key});

  @override
  Widget build(BuildContext context) {
    final updater = Updater(
      owner: 'claw-sweeper',
      repo: 'uninstall-everything-claw',
      currentVersion: '0.1.0',
    );

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ScannerBloc()),
        BlocProvider(create: (_) => UninstallBloc()),
        BlocProvider(create: (_) => UpdateBloc(updater)),
      ],
      child: MaterialApp(
        title: 'ClawSweeper',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.deepPurple,
          useMaterial3: true,
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          colorSchemeSeed: Colors.deepPurple,
          useMaterial3: true,
          brightness: Brightness.dark,
        ),
        themeMode: ThemeMode.system,
        home: const HomePage(),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    ScanPage(),
    SettingsPage(),
    AboutPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.search),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
          NavigationDestination(
            icon: Icon(Icons.info_outline),
            label: 'About',
          ),
        ],
      ),
    );
  }
}
