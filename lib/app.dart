import 'package:flutter/material.dart';

import 'src/screens/arrangement_screen.dart';

class MusicDawApp extends StatelessWidget {
  const MusicDawApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: const Color(0xFF19D3B3),
            brightness: Brightness.dark,
          ).copyWith(
            surface: const Color(0xFF111825),
            surfaceContainerHighest: const Color(0xFF1B2433),
            primary: const Color(0xFF3BE3C6),
            secondary: const Color(0xFFFFB86B),
            tertiary: const Color(0xFF77A8FF),
          ),
      scaffoldBackgroundColor: const Color(0xFF070B12),
    );

    return MaterialApp(
      title: 'PineWave',
      debugShowCheckedModeBanner: false,
      theme: baseTheme.copyWith(
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF111825),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFF263345)),
          ),
        ),
        sliderTheme: baseTheme.sliderTheme.copyWith(
          activeTrackColor: const Color(0xFF3BE3C6),
          inactiveTrackColor: const Color(0xFF293548),
          thumbColor: const Color(0xFFFFB86B),
          overlayColor: const Color(0x333BE3C6),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF071C1A),
          contentTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            height: 1.25,
          ),
          closeIconColor: Colors.white,
          elevation: 12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF00E0A4), width: 1.2),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: const ArrangementScreen(),
    );
  }
}
