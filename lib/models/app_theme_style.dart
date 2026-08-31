import 'package:flutter/material.dart';

enum AppThemeStyle {
  fresh(
    label: '프레시',
    description: '싱그러운 그린과 따뜻한 아이보리',
    seedColor: Color(0xFF285D46),
    accentColor: Color(0xFFE36F50),
    backgroundColor: Color(0xFFF7F5EF),
  ),
  minimal(
    label: '미니멀',
    description: '차분한 블루와 맑은 회백색',
    seedColor: Color(0xFF355D78),
    accentColor: Color(0xFF517DA0),
    backgroundColor: Color(0xFFF3F6F9),
  ),
  cozy(
    label: '포근함',
    description: '부드러운 크림과 생기 있는 오렌지',
    seedColor: Color(0xFF416B3B),
    accentColor: Color(0xFFF1943C),
    backgroundColor: Color(0xFFFFF7E8),
  );

  const AppThemeStyle({
    required this.label,
    required this.description,
    required this.seedColor,
    required this.accentColor,
    required this.backgroundColor,
  });

  final String label;
  final String description;
  final Color seedColor;
  final Color accentColor;
  final Color backgroundColor;

  static AppThemeStyle fromName(String? name) {
    for (final style in values) {
      if (style.name == name) return style;
    }
    return AppThemeStyle.fresh;
  }
}

ThemeData buildAppTheme(AppThemeStyle style) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: style.seedColor,
  ).copyWith(secondary: style.accentColor, surface: style.backgroundColor);

  return ThemeData(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: style.backgroundColor,
    useMaterial3: true,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Color.alphaBlend(
        Colors.white.withValues(alpha: 0.72),
        style.backgroundColor,
      ),
      indicatorColor: colorScheme.primaryContainer,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: style.accentColor,
      foregroundColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: const OutlineInputBorder(),
      filled: true,
      fillColor: Color.alphaBlend(
        Colors.white.withValues(alpha: 0.82),
        style.backgroundColor,
      ),
    ),
  );
}
