
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme.dart';
import 'features/home/home_screen.dart';
import 'features/history/history_screen.dart';
import 'features/scan/scan_screen.dart';
import 'features/splash/splash_screen.dart';

class EcoPlantApp extends StatelessWidget {
  const EcoPlantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoPlant AI',
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      home: const SplashScreen(
        nextScreen: AppShell(),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const Color _background = Color(0xFFF7F8F3);
  static const Color _primary = Color(0xFF164D2C);
  static const Color _muted = Color(0xFF637367);
  static const Color _softGreen = Color(0xFFE7EDDF);
  static const Color _border = Color(0xFFDDE4D7);

  int _tab = 0;

  void _select(int value) {
    setState(() => _tab = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,

      appBar: _buildAppBar(),

      // Fungsi navigasi asli tetap dipertahankan.
      body: switch (_tab) {
        0 => HomeScreen(
          onScan: () => _select(1),
          onHistory: () => _select(2),
        ),
        1 => const ScanScreen(),
        _ => HistoryScreen(
          onScan: () => _select(1),
        ),
      },

      bottomNavigationBar: _buildNavigationBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _background,
      foregroundColor: _primary,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      automaticallyImplyLeading: false,
      centerTitle: false,
      toolbarHeight: 64,
      titleSpacing: 20,

      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),

      // Judul halaman di kiri.
      title: Text(
        ['Home', 'Scan Daun', 'Riwayat'][_tab],
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.6,
          color: _primary,
        ),
      ),

      // Logo EcoPlant di kanan.
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.asset(
                'assets/icons/LOGO.png',
                width: 34,
                height: 34,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              ),
            ),
          ),
        ),
      ],

      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Divider(
            height: 1,
            thickness: 0.7,
            color: _border,
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: _border,
            width: 0.7,
          ),
        ),
      ),
      child: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: _softGreen,
          elevation: 0,

          labelTextStyle:
              WidgetStateProperty.resolveWith<TextStyle>(
            (states) {
              final selected =
                  states.contains(WidgetState.selected);

              return TextStyle(
                fontSize: 12,
                fontWeight: selected
                    ? FontWeight.w500
                    : FontWeight.w400,
                color: selected ? _primary : _muted,
              );
            },
          ),

          iconTheme:
              WidgetStateProperty.resolveWith<IconThemeData>(
            (states) {
              final selected =
                  states.contains(WidgetState.selected);

              return IconThemeData(
                size: 24,
                color: selected ? _primary : _muted,
              );
            },
          ),
        ),

        child: NavigationBar(
          height: 68,
          elevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          indicatorColor: _softGreen,
          selectedIndex: _tab,
          onDestinationSelected: _select,

          labelBehavior:
              NavigationDestinationLabelBehavior.alwaysShow,

          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Beranda',
            ),
            NavigationDestination(
              icon: Icon(Icons.camera_alt_outlined),
              selectedIcon: Icon(Icons.camera_alt_rounded),
              label: 'Scan',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_rounded),
              label: 'Riwayat',
            ),
          ],
        ),
      ),
    );
  }
}
