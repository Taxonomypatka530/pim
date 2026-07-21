import 'package:flutter/material.dart';

/// The single accent color of the whole app — the soft red from the PIM logo.
/// Everything that "pops" (buttons, the device hero card, bubbles, selected
/// states, the radar, section headers) uses exactly this red. Backgrounds stay
/// clean white; the online indicator stays green. No graphite, no yellow.
const Color kAccent = Color(0xFFFF5A5F);

/// Extra semantic colors that don't fit Material's [ColorScheme] cleanly.
///
/// [accent] is the brand red for small UI touches (section headers, selected
/// states, the radar). [online] is the presence indicator.
@immutable
class BrandColors extends ThemeExtension<BrandColors> {
  const BrandColors({required this.accent, required this.online});

  final Color accent;
  final Color online;

  static BrandColors of(BuildContext context) =>
      Theme.of(context).extension<BrandColors>()!;

  @override
  BrandColors copyWith({Color? accent, Color? online}) =>
      BrandColors(accent: accent ?? this.accent, online: online ?? this.online);

  @override
  BrandColors lerp(BrandColors? other, double t) {
    if (other == null) return this;
    return BrandColors(
      accent: Color.lerp(accent, other.accent, t)!,
      online: Color.lerp(online, other.online, t)!,
    );
  }
}

// ---------------------------------------------------------------------------
// Light scheme — pure white, soft-red accent. No graphite, no yellow, no purple.
// ---------------------------------------------------------------------------
const ColorScheme _lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: kAccent,
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFFFDBDA),
  onPrimaryContainer: Color(0xFF40000A),
  secondary: Color(0xFF5A5D63),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFE4E7EB),
  onSecondaryContainer: Color(0xFF1A1C1E),
  tertiary: Color(0xFF4A4D52),
  onTertiary: Color(0xFFFFFFFF),
  tertiaryContainer: Color(0xFFE4E7EB),
  onTertiaryContainer: Color(0xFF1A1C1E),
  error: Color(0xFFB3261E),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFF9DEDC),
  onErrorContainer: Color(0xFF410E0B),
  surface: Color(0xFFFFFFFF),
  onSurface: Color(0xFF1A1C1E),
  surfaceDim: Color(0xFFDADCE0),
  surfaceBright: Color(0xFFFFFFFF),
  surfaceContainerLowest: Color(0xFFFFFFFF),
  surfaceContainerLow: Color(0xFFF5F6F8),
  surfaceContainer: Color(0xFFEFF1F4),
  surfaceContainerHigh: Color(0xFFEAECEF),
  surfaceContainerHighest: Color(0xFFE4E7EB),
  onSurfaceVariant: Color(0xFF43474E),
  outline: Color(0xFF73777F),
  outlineVariant: Color(0xFFC3C7CF),
  inverseSurface: Color(0xFF2E3133),
  onInverseSurface: Color(0xFFF1F3F6),
  inversePrimary: Color(0xFFFFB3B4),
  surfaceTint: Color(0xFFFFFFFF),
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
);

// ---------------------------------------------------------------------------
// Dark scheme — neutral near-black, same soft-red accent.
// ---------------------------------------------------------------------------
const ColorScheme _darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: kAccent,
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFF5A1D22),
  onPrimaryContainer: Color(0xFFFFDBDA),
  secondary: Color(0xFFC4C7CD),
  onSecondary: Color(0xFF2A2C30),
  secondaryContainer: Color(0xFF3A3D42),
  onSecondaryContainer: Color(0xFFE4E7EB),
  tertiary: Color(0xFFC4C7CD),
  onTertiary: Color(0xFF2A2C30),
  tertiaryContainer: Color(0xFF3A3D42),
  onTertiaryContainer: Color(0xFFE4E7EB),
  error: Color(0xFFF2B8B5),
  onError: Color(0xFF601410),
  errorContainer: Color(0xFF8C1D18),
  onErrorContainer: Color(0xFFF9DEDC),
  surface: Color(0xFF131417),
  onSurface: Color(0xFFE4E6EA),
  surfaceDim: Color(0xFF131417),
  surfaceBright: Color(0xFF393A3E),
  surfaceContainerLowest: Color(0xFF0E0F11),
  surfaceContainerLow: Color(0xFF1B1C1F),
  surfaceContainer: Color(0xFF1F2023),
  surfaceContainerHigh: Color(0xFF2A2B2E),
  surfaceContainerHighest: Color(0xFF343539),
  onSurfaceVariant: Color(0xFFC4C6CC),
  outline: Color(0xFF8E9199),
  outlineVariant: Color(0xFF44474C),
  inverseSurface: Color(0xFFE4E6EA),
  onInverseSurface: Color(0xFF2E3133),
  inversePrimary: Color(0xFF7F2A2E),
  surfaceTint: Color(0xFF131417),
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
);

const BrandColors _lightBrand = BrandColors(
  accent: kAccent,
  online: Color(0xFF1E9E56),
);

const BrandColors _darkBrand = BrandColors(
  accent: kAccent,
  online: Color(0xFF48E08B),
);

ThemeData pimTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme = isDark ? _darkScheme : _lightScheme;
  final brand = isDark ? _darkBrand : _lightBrand;

  const transitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: ZoomPageTransitionsBuilder(),
      TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
    },
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    extensions: [brand],
    pageTransitionsTheme: transitions,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    splashFactory: InkSparkle.splashFactory,
  );
}
