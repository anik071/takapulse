import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TakaPulseColors {
  // Core Canvas & Glass Surfaces
  static const Color background = Color(0xFF101320);
  static const Color surfaceContainerLowest = Color(0xFF0A0D1A);
  static const Color surfaceContainerLow = Color(0xFF181B28);
  static const Color surfaceContainer = Color(0xFF1C1F2D);
  static const Color surfaceContainerHigh = Color(0xFF262937);
  static const Color surfaceContainerHighest = Color(0xFF313443);

  // Brand Accents (Emerald Mint & Electric Cyan)
  static const Color primary = Color(0xFF47F3BB);
  static const Color primaryContainer = Color(0xFF06D6A0);
  static const Color onPrimary = Color(0xFF003827);
  static const Color onPrimaryFixed = Color(0xFF002116);

  static const Color secondary = Color(0xFFD3FBFF);
  static const Color secondaryFixed = Color(0xFF7DF4FF);
  static const Color secondaryFixedDim = Color(0xFF00DBE9);
  static const Color secondaryContainer = Color(0xFF00EEFC);

  static const Color tertiary = Color(0xFFFFCCCF);
  static const Color error = Color(0xFFFFB4AB);

  // Text & Borders
  static const Color onSurface = Color(0xFFE0E1F4);
  static const Color onSurfaceVariant = Color(0xFFBACAC1);
  static const Color outlineVariant = Color(0xFF3B4A43);
  static const Color ambientIndigo = Color(0xFF1E1B4B);
}

class TakaPulseTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: TakaPulseColors.background,
      colorScheme: const ColorScheme.dark(
        primary: TakaPulseColors.primary,
        primaryContainer: TakaPulseColors.primaryContainer,
        onPrimary: TakaPulseColors.onPrimary,
        secondary: TakaPulseColors.secondary,
        secondaryContainer: TakaPulseColors.secondaryContainer,
        tertiary: TakaPulseColors.tertiary,
        surface: TakaPulseColors.background,
        onSurface: TakaPulseColors.onSurface,
        onSurfaceVariant: TakaPulseColors.onSurfaceVariant,
        error: TakaPulseColors.error,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 38,
          fontWeight: FontWeight.w700,
          color: TakaPulseColors.onSurface,
          letterSpacing: -0.8,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: TakaPulseColors.onSurface,
        ),
        headlineSmall: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: TakaPulseColors.onSurface,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: TakaPulseColors.onSurface,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: TakaPulseColors.onSurface,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: TakaPulseColors.onSurface,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: TakaPulseColors.onSurfaceVariant,
        ),
        labelLarge: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: TakaPulseColors.onSurface,
        ),
        labelMedium: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: TakaPulseColors.onSurface,
        ),
        labelSmall: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: TakaPulseColors.onSurfaceVariant,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Reusable Frosted Glass Container matching Stitch's `backdrop-blur-2xl` cards
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? tintColor;
  final double opacity;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.borderRadius = 24,
    this.tintColor,
    this.opacity = 0.70,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 40,
            offset: const Offset(0, 16),
            spreadRadius: -8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: (tintColor ?? TakaPulseColors.surfaceContainer)
                  .withOpacity(opacity),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: Colors.white.withOpacity(0.07),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Ambient Radial Glow Canvas matching the Stitch background orbs
class AmbientScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;

  const AmbientScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      backgroundColor: TakaPulseColors.background,
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      body: Stack(
        children: [
          // Top-left Indigo Orb
          Positioned(
            top: -120,
            left: -80,
            child: _GlowOrb(
              size: 320,
              color: TakaPulseColors.ambientIndigo.withOpacity(0.65),
            ),
          ),
          // Right-center Cyan Orb
          Positioned(
            top: MediaQuery.of(context).size.height * 0.25,
            right: -100,
            child: _GlowOrb(
              size: 280,
              color: TakaPulseColors.secondaryContainer.withOpacity(0.10),
            ),
          ),
          // Bottom-left Emerald Orb
          Positioned(
            bottom: 80,
            left: -60,
            child: _GlowOrb(
              size: 320,
              color: TakaPulseColors.primaryContainer.withOpacity(0.10),
            ),
          ),
          SafeArea(
            bottom: false,
            child: body,
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withOpacity(0.0)],
          stops: const [0.1, 1.0],
        ),
      ),
    );
  }
}