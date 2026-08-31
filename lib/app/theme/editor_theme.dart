import 'package:flutter/material.dart';

abstract final class EditorTheme {
  static const accent = Color(0xFFFFB300);
  static const panelDark = Color(0xFF17191E);
  static const canvasDark = Color(0xFF090A0D);
  static const borderDark = Color(0xFF30343D);

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      surface: const Color(0xFF1E2127),
    );
    return _base(scheme).copyWith(
      scaffoldBackgroundColor: const Color(0xFF111318),
      dividerColor: borderDark,
    );
  }

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFE09A00),
      brightness: Brightness.light,
      surface: const Color(0xFFF4F5F7),
    );
    return _base(scheme).copyWith(
      scaffoldBackgroundColor: const Color(0xFFE8EAF0),
      dividerColor: const Color(0xFFC8CBD2),
    );
  }

  static ThemeData _base(ColorScheme scheme) => ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    visualDensity: VisualDensity.compact,
    fontFamily: 'Arial',
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 450),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 4),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(32, 32)),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(5)),
    ),
  );
}
