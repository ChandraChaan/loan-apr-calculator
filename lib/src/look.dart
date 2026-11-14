import 'package:flutter/material.dart';

/// A bank passbook: pale green ruled paper, dark green ink, and a red stamp
/// for the number the lender would rather you did not see.
class Look {
  const Look._({
    required this.paper,
    required this.page,
    required this.ink,
    required this.muted,
    required this.rule,
    required this.red,
    required this.good,
  });

  final Color paper, page, ink, muted, rule, red, good;

  static const light = Look._(
    paper: Color(0xFFE4EBE3),
    page: Color(0xFFF7FAF4),
    ink: Color(0xFF173B2E),
    muted: Color(0xFF66766D),
    rule: Color(0xFFCFDCCF),
    red: Color(0xFFB33A2A),
    good: Color(0xFF1F7A4D),
  );

  static const dark = Look._(
    paper: Color(0xFF0E1512),
    page: Color(0xFF17201B),
    ink: Color(0xFFD4E8DC),
    muted: Color(0xFF93A69B),
    rule: Color(0xFF2B3A32),
    red: Color(0xFFF0806E),
    good: Color(0xFF63CC95),
  );

  static Look of(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? dark : light;

  static const figures = [FontFeature.tabularFigures()];

  TextStyle label() => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
    color: muted,
  );

  ThemeData theme(Brightness b) {
    final line = UnderlineInputBorder(
      borderSide: BorderSide(color: rule, width: 1.2),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme(
        brightness: b,
        primary: ink,
        onPrimary: page,
        secondary: good,
        onSecondary: Colors.white,
        error: red,
        onError: Colors.white,
        surface: page,
        onSurface: ink,
      ),
      scaffoldBackgroundColor: paper,
      dividerColor: rule,
      inputDecorationTheme: InputDecorationTheme(
        border: line,
        enabledBorder: line,
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: ink, width: 1.8),
        ),
        labelStyle: TextStyle(color: muted),
        floatingLabelStyle: TextStyle(color: ink, fontWeight: FontWeight.w600),
        isDense: true,
        contentPadding: const EdgeInsets.only(top: 6, bottom: 8),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: WidgetStatePropertyAll(BorderSide(color: rule)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? ink : page,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? page : ink,
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: BorderSide(color: rule),
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
