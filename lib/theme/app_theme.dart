import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFFD46211);
  static const Color primaryLight = Color(0xFFE87A2A);
  static const Color primaryDark = Color(0xFFB04E0A);

  static const Color forest = Color(0xFF1E3A2F);
  static const Color forestLight = Color(0xFF2D5A48);
  static const Color forestDark = Color(0xFF0F1F19);

  static const Color background = Color(0xFFF7F7F4);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF0EFEC);

  static const Color textPrimary = Color(0xFF171717);
  static const Color textSecondary = Color(0xFF686868);
  static const Color textTertiary = Color(0xFF9A9A9A);
  static const Color textOnDark = Color(0xFFFFFFFF);

  static const Color glassBg = Color(0xCCFFFFFF);
  static const Color glassBorder = Color(0x40FFFFFF);
  static const Color glassShadow = Color(0x1A000000);

  static const Color success = Color(0xFF2FA865);
  static const Color warning = Color(0xFFF5A524);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF2563EB);

  static const Color divider = Color(0xFFE8E8E5);
  static const Color shimmer = Color(0xFFE0E0DC);
  static const Color scrim = Color(0x8A0F1F19);
  static const Color emergency = Color(0xFFB91C1C);
  static const Color routeBlue = Color(0xFF2563EB);
  static const Color sky = Color(0xFF0EA5E9);
  static const Color amber = Color(0xFFD88300);
}

class AppTypography {
  AppTypography._();

  // Google Sans is bundled from the Google Fonts served truetype assets.
  static const String fontFamily = 'Google Sans';

  static TextStyle style({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w400,
    double height = 1.3,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle get displayLarge =>
      style(fontSize: 38, fontWeight: FontWeight.w700, height: 1.06);
  static TextStyle get displayMedium =>
      style(fontSize: 32, fontWeight: FontWeight.w700, height: 1.08);
  static TextStyle get displaySmall =>
      style(fontSize: 27, fontWeight: FontWeight.w700, height: 1.12);
  static TextStyle get headlineLarge =>
      style(fontSize: 23, fontWeight: FontWeight.w700, height: 1.16);
  static TextStyle get headlineMedium =>
      style(fontSize: 20, fontWeight: FontWeight.w700, height: 1.22);
  static TextStyle get headlineSmall =>
      style(fontSize: 18, fontWeight: FontWeight.w700, height: 1.26);
  static TextStyle get titleLarge =>
      style(fontSize: 16, fontWeight: FontWeight.w600, height: 1.35);
  static TextStyle get titleMedium =>
      style(fontSize: 14, fontWeight: FontWeight.w600, height: 1.4);
  static TextStyle get titleSmall =>
      style(fontSize: 12, fontWeight: FontWeight.w600, height: 1.4);
  static TextStyle get bodyLarge =>
      style(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5);
  static TextStyle get bodyMedium =>
      style(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5);
  static TextStyle get bodySmall =>
      style(fontSize: 12, fontWeight: FontWeight.w400, height: 1.5);
  static TextStyle get labelLarge =>
      style(fontSize: 14, fontWeight: FontWeight.w600, height: 1.3);
  static TextStyle get labelMedium =>
      style(fontSize: 12, fontWeight: FontWeight.w600, height: 1.3);
  static TextStyle get labelSmall =>
      style(fontSize: 10, fontWeight: FontWeight.w600, height: 1.3);
  static TextStyle get buttonLarge =>
      style(fontSize: 16, fontWeight: FontWeight.w600, height: 1.2);
  static TextStyle get buttonMedium =>
      style(fontSize: 14, fontWeight: FontWeight.w600, height: 1.2);
  static TextStyle get inputText =>
      style(fontSize: 13, fontWeight: FontWeight.w500, height: 1.4);
  static TextStyle get caption =>
      style(fontSize: 11, fontWeight: FontWeight.w500, height: 1.4);
  static TextStyle get overline =>
      style(fontSize: 10, fontWeight: FontWeight.w600, height: 1.3);
  static TextStyle get numeric =>
      style(fontSize: 28, fontWeight: FontWeight.w700, height: 1.0);
  static TextStyle get telemetry =>
      style(fontSize: 20, fontWeight: FontWeight.w700, height: 1.05);
}

class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
  static const double massive = 48;
  static const double giant = 64;
}

class AppRadius {
  AppRadius._();

  static const double sm = 6;
  static const double md = 8;
  static const double lg = 14;
  static const double xl = 18;
  static const double xxl = 22;
  static const double xxxl = 28;
  static const double pill = 999;
}

class AppSurfaces {
  AppSurfaces._();

  static const Color page = AppColors.background;
  static const Color card = AppColors.surface;
  static const Color muted = AppColors.surfaceAlt;
  static Color selected = AppColors.primary.withValues(alpha: 0.1);
  static Color success = AppColors.success.withValues(alpha: 0.12);
  static Color warning = AppColors.warning.withValues(alpha: 0.14);
  static Color danger = AppColors.error.withValues(alpha: 0.1);
  static Color glass = AppColors.surface.withValues(alpha: 0.82);
  static Color glassStrong = AppColors.surface.withValues(alpha: 0.9);
}

class AppShadows {
  AppShadows._();

  static List<BoxShadow> get sm => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get md => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get lg => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get glass => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 28,
      offset: const Offset(0, 14),
    ),
  ];

  static List<BoxShadow> get primary => [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.25),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
}

class AppDurations {
  AppDurations._();

  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration pageTransition = Duration(milliseconds: 300);
}

class AppCurves {
  AppCurves._();

  static const Curve easeInOutCubic = Curves.easeInOutCubic;
  static const Curve easeOutCubic = Curves.easeOutCubic;
  static const Curve easeInCubic = Curves.easeInCubic;
  static const Curve easeOutBack = Curves.easeOutBack;
  static const Curve easeInOutBack = Curves.easeInOutBack;
  static const Curve spring = Curves.fastOutSlowIn;
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: false);
    return base.copyWith(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.forest,
        primaryContainer: AppColors.primaryLight,
        secondaryContainer: AppColors.forestLight,
        surface: AppColors.surface,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: _textTheme,
      primaryTextTheme: _textTheme,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionColor: AppColors.primary.withValues(alpha: 0.22),
        selectionHandleColor: AppColors.primary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: AppColors.divider),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        titleTextStyle: AppTypography.headlineSmall.copyWith(
          color: AppColors.forest,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.forest,
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStatePropertyAll(AppTypography.labelSmall),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.primary : AppColors.textTertiary,
          );
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        elevation: 0,
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textTertiary,
        selectedLabelStyle: AppTypography.labelSmall,
        unselectedLabelStyle: AppTypography.labelSmall,
        type: BottomNavigationBarType.fixed,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 10,
        shadowColor: Colors.black.withValues(alpha: 0.14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.divider),
        ),
        textStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        labelTextStyle: WidgetStatePropertyAll(
          AppTypography.bodyMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: AppTypography.buttonMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.forest,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: AppTypography.buttonMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
          side: const BorderSide(color: AppColors.divider, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppTypography.buttonMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface.withValues(alpha: 0.88),
        floatingLabelStyle: AppTypography.labelMedium.copyWith(
          color: AppColors.primary,
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          borderSide: const BorderSide(color: AppColors.divider, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        labelStyle: AppTypography.labelMedium.copyWith(
          color: AppColors.textSecondary,
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.textTertiary,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceAlt,
        labelStyle: AppTypography.labelSmall,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        side: BorderSide.none,
      ),
    );
  }

  static TextTheme get _textTheme => TextTheme(
    displayLarge: AppTypography.displayLarge,
    displayMedium: AppTypography.displayMedium,
    displaySmall: AppTypography.displaySmall,
    headlineLarge: AppTypography.headlineLarge,
    headlineMedium: AppTypography.headlineMedium,
    headlineSmall: AppTypography.headlineSmall,
    titleLarge: AppTypography.titleLarge,
    titleMedium: AppTypography.titleMedium,
    titleSmall: AppTypography.titleSmall,
    bodyLarge: AppTypography.bodyLarge,
    bodyMedium: AppTypography.bodyMedium,
    bodySmall: AppTypography.bodySmall,
    labelLarge: AppTypography.labelLarge,
    labelMedium: AppTypography.labelMedium,
    labelSmall: AppTypography.labelSmall,
  ).apply(fontFamily: AppTypography.fontFamily);
}
