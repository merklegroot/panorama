import 'package:flutter/material.dart';

class PanoramaColors {
  static const blue = Color(0xFF2F73DA);
  static const blueSoft = Color(0xFFDCECFF);
  static const ink = Color(0xFF1C2430);
  static const muted = Color(0xFF6D7785);
  static const line = Color(0x1A19263A);
  static const panel = Color(0xE0F9FAFC);
  static const sidebar = Color(0xC2E8ECF2);
  static const selected = Color(0xFFDCECFF);
  static const danger = Color(0xFFC0392B);
  static const navActive = Color(0xFF174F99);
}

ThemeData buildPanoramaTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: PanoramaColors.blue,
      brightness: Brightness.light,
    ),
    fontFamily: '.AppleSystemUIFont',
  );

  return base.copyWith(
    scaffoldBackgroundColor: PanoramaColors.panel,
    textTheme: base.textTheme.apply(
      bodyColor: PanoramaColors.ink,
      displayColor: PanoramaColors.ink,
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        color: const Color(0xF01C2430),
        borderRadius: BorderRadius.circular(6),
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
    ),
  );
}
