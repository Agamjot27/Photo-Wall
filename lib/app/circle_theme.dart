import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

abstract final class CirclePalette {
  static const ink = Color(0xFF101419);
  static const lime = Color(0xFFA5CE41);
  static const paper = Color(0xFFFAFBF8);
}

final circleLightTheme = FThemeData(
  colors: FThemes.zinc.light.colors.copyWith(
    background: CirclePalette.paper,
    foreground: const Color(0xFF1E2B37),
    primary: const Color(0xFF48670D),
    primaryForeground: Colors.white,
    secondary: const Color(0xFFEAF4D1),
    secondaryForeground: CirclePalette.ink,
    muted: const Color(0xFFF0F3E9),
    mutedForeground: const Color(0xFF58646A),
    border: const Color(0xFFDFE5D6),
  ),
);

final circleDarkTheme = FThemeData(
  colors: FThemes.zinc.dark.colors.copyWith(
    background: CirclePalette.ink,
    foreground: const Color(0xFFF7F9F3),
    primary: CirclePalette.lime,
    primaryForeground: CirclePalette.ink,
    secondary: const Color(0xFF293519),
    secondaryForeground: const Color(0xFFF7F9F3),
    muted: const Color(0xFF252C2D),
    mutedForeground: const Color(0xFFB6C0B2),
    border: const Color(0xFF394340),
  ),
);

class CircleDarkHeader extends StatelessWidget {
  const CircleDarkHeader({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => FTheme(
    data: circleDarkTheme,
    child: ColoredBox(color: CirclePalette.ink, child: child),
  );
}
