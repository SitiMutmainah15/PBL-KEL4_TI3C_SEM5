import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'features/home/home_screen.dart';
import 'features/history/history_screen.dart';
import 'features/scan/scan_screen.dart';

class EcoPlantApp extends StatelessWidget {
  const EcoPlantApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'EcoPlant AI',
    debugShowCheckedModeBanner: false,
    theme: appTheme(),
    home: const AppShell(),
  );
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;
  void _select(int value) => setState(() => _tab = value);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(['EcoPlant AI', 'Scan Daun', 'Riwayat'][_tab])),
    body: switch (_tab) {
      0 => HomeScreen(onScan: () => _select(1), onHistory: () => _select(2)),
      1 => const ScanScreen(),
      _ => HistoryScreen(onScan: () => _select(1)),
    },
    bottomNavigationBar: NavigationBar(
      selectedIndex: _tab,
      onDestinationSelected: _select,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Beranda',
        ),
        NavigationDestination(
          icon: Icon(Icons.camera_alt_outlined),
          selectedIcon: Icon(Icons.camera_alt),
          label: 'Scan',
        ),
        NavigationDestination(icon: Icon(Icons.history), label: 'Riwayat'),
      ],
    ),
  );
}
