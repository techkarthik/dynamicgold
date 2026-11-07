import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GlassTheme {
  // Ultra-clean luxury pearl white & slate palette
  static const Color bgDark = Color(0xFFF8FAFC); // Main porcelain canvas
  static const Color bgDarkSecondary = Color(0xFFFFFFFF); // Pure white card & sidebar
  static const Color bgSurface = Color(0xFFFFFFFF); // Crisp white surface
  static const Color bgSurfaceMuted = Color(0xFFF1F5F9); // Slate-100 muted surface

  // Vibrant luxury accent colors
  static const Color primaryNeon = Color(0xFF4F46E5); // Royal Indigo
  static const Color secondaryNeon = Color(0xFF7C3AED); // Purple
  static const Color accentEmerald = Color(0xFF059669); // Emerald Green
  static const Color accentCyan = Color(0xFF0284C7); // Cyan Blue
  static const Color accentRose = Color(0xFFE11D48); // Rose
  static const Color accentAmber = Color(0xFFD97706); // Luxury Gold / Amber

  // Glass card styling (Light mode frosted glass)
  static const Color glassFill = Color(0xF2FFFFFF); // 95% translucent white frosted glass
  static const Color glassFillHover = Color(0xFFFFFFFF); // Pure crisp white
  static const Color glassBorder = Color(0xFFE2E8F0); // Crisp light border
  static const Color glassBorderGlow = Color(0x334F46E5); // Indigo glow border

  // Text Colors (High contrast, crisp dark bold typography)
  static const Color textPrimary = Color(0xFF0F172A); // Obsidian Slate-900 (ultra dark, readable)
  static const Color textSecondary = Color(0xFF334155); // Slate-700 (dark bold secondary)
  static const Color textMuted = Color(0xFF64748B); // Slate-500 (crisp medium slate)

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF6366F1), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient emeraldGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cyanGradient = LinearGradient(
    colors: [Color(0xFF0284C7), Color(0xFF2563EB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const RadialGradient backgroundMesh = RadialGradient(
    center: Alignment(-0.8, -0.6),
    radius: 1.2,
    colors: [
      Color(0x0C4F46E5),
      Color(0x00000000),
    ],
  );

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: bgDark,
      cardColor: bgDarkSecondary,
      primaryColor: primaryNeon,
      colorScheme: const ColorScheme.light(
        primary: primaryNeon,
        secondary: secondaryNeon,
        surface: bgDarkSecondary,
        error: accentRose,
        onSurface: textPrimary,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        ThemeData.light().textTheme,
      ).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      useMaterial3: true,
    );
  }

  // Backward compatibility alias
  static ThemeData get darkTheme => lightTheme;
}
