// utils/theme.dart — VaultX design system

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FColors {
  FColors._();
  static const bg         = Color(0xFF0A0A0B);
  static const surface    = Color(0xFF18181B);
  static const surfaceAlt = Color(0xFF27272A);
  static const border     = Color(0x0FFFFFFF);
  static const borderMid  = Color(0x1EFFFFFF);
  static const text       = Color(0xFFFAFAFA);
  static const textMuted  = Color(0xFFA1A1AA);
  static const textDim    = Color(0xFF52525B);
  static const emerald    = Color(0xFF10B981);
  static const emeraldDim = Color(0x2610B981);
  static const emeraldBdr = Color(0x4D10B981);
  static const emeraldDk  = Color(0xFF064E3B);
  static const red        = Color(0xFFEF4444);
  static const redDim     = Color(0x14EF4444);
  static const amber      = Color(0xFFF59E0B);
  static const amberDim   = Color(0x19F59E0B);
  static const blue       = Color(0xFF3B82F6);
  static const blueDim    = Color(0x193B82F6);
  static const white      = Color(0xFFFFFFFF);
  static const black      = Color(0xFF000000);
}

class FText {
  FText._();
  static TextStyle label({double size = 10, Color? color,
      FontWeight weight = FontWeight.w800, double letterSpacing = 1.5}) =>
    TextStyle(fontSize: size, fontWeight: weight,
        color: color ?? FColors.textDim, letterSpacing: letterSpacing);
  static TextStyle body({double size = 14, Color? color, FontWeight weight = FontWeight.w400}) =>
    TextStyle(fontSize: size, fontWeight: weight, color: color ?? FColors.textMuted);
  static TextStyle title({double size = 16, Color? color}) =>
    TextStyle(fontSize: size, fontWeight: FontWeight.w700, color: color ?? FColors.text);
}

ThemeData buildVaultXTheme() {
  final base = ThemeData.dark();
  return base.copyWith(
    scaffoldBackgroundColor: FColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: FColors.emerald, secondary: FColors.emerald,
      surface: FColors.surface, error: FColors.red,
    ),
    textTheme: GoogleFonts.interTextTheme(base.textTheme)
        .apply(bodyColor: FColors.text, displayColor: FColors.text),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xF20A0A0B), elevation: 0, centerTitle: false,
      iconTheme: IconThemeData(color: FColors.textMuted),
      titleTextStyle: TextStyle(color: FColors.text, fontSize: 18,
          fontWeight: FontWeight.w800, letterSpacing: 2),
    ),
    dividerColor: FColors.border,
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: const Color(0x0AFFFFFF),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: FColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: FColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: FColors.emerald, width: 1.5)),
      hintStyle: const TextStyle(color: FColors.textDim),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(FColors.white),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? FColors.emerald : FColors.surfaceAlt),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: FColors.emerald, foregroundColor: FColors.emeraldDk,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        minimumSize: const Size(double.infinity, 52),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2),
      ),
    ),
  );
}

// Shared widgets
class FCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? color;
  final double radius;
  const FCard({super.key, required this.child, this.padding, this.color, this.radius = 20});
  @override
  Widget build(BuildContext context) => Container(
    padding: padding ?? const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color ?? const Color(0x06FFFFFF),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: FColors.border),
    ),
    child: child,
  );
}

class FDivider extends StatelessWidget {
  const FDivider({super.key});
  @override
  Widget build(BuildContext context) =>
      const Divider(color: FColors.border, height: 1, thickness: 1);
}

class FSectionLabel extends StatelessWidget {
  final String text;
  const FSectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(text, style: FText.label()),
  );
}
