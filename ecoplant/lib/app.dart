import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'features/home/home_screen.dart';
import 'features/history/history_screen.dart';
import 'features/scan/scan_screen.dart';
import 'features/splash/splash_screen.dart';

class EcoPlantApp extends StatelessWidget {
  const EcoPlantApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'EcoPlant AI',
    debugShowCheckedModeBanner: false,
    theme: appTheme(),

    // Splash Screen tampil pertama kali.
    home: const SplashScreen(nextScreen: AppShell()),
  );
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;

  void _select(int value) {
    setState(() => _tab = value);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: _tab == 0
          ? const Row(
              children: [
                Icon(Icons.eco_rounded, color: Color(0xFF4F7B3A)),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ECOPLANT AI',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1,
                        color: Color(0xFF667066),
                      ),
                    ),
                    Text(
                      'Home',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Text(['EcoPlant AI', 'Scan Daun', 'Riwayat'][_tab]),
      actions: _tab == 0
          ? const [
              Padding(
                padding: EdgeInsets.only(right: 20),
                child: CircleAvatar(
                  radius: 17,
                  backgroundColor: Color(0xFF4F7B3A),
                  child: Icon(
                    Icons.person_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ]
          : null,
    ),
    body: switch (_tab) {
      0 => HomeScreen(onScan: () => _select(1), onHistory: () => _select(2)),
      1 => const ScanScreen(),
      _ => HistoryScreen(onScan: () => _select(1)),
    },
    bottomNavigationBar: NavigationBar(
      height: 70,
      selectedIndex: _tab,
      onDestinationSelected: _select,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Beranda',
        ),
        NavigationDestination(
          icon: _ScanNavigationIcon(),
          selectedIcon: _ScanNavigationIcon(),
          label: 'Scan',
        ),
        NavigationDestination(icon: Icon(Icons.history), label: 'Riwayat'),
      ],
    ),
  );
}

class _ScanNavigationIcon extends StatelessWidget {
  const _ScanNavigationIcon();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(9),
    decoration: BoxDecoration(
      color: const Color(0xFF4F7B3A),
      borderRadius: BorderRadius.circular(13),
    ),
    child: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 22),
  );
}
