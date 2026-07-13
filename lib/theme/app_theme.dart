import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFFE8EAED);
  static const surface = Color(0xFFF3F4F6);
  static const card = Color(0xFFFAFBFC);
  static const white = Colors.white;
  static const gray50 = Color(0xFFEEEFF2);
  static const gray100 = Color(0xFFF3F4F6);
  static const gray200 = Color(0xFFE5E7EB);
  static const gray300 = Color(0xFFD1D5DB);
  static const gray400 = Color(0xFF9CA3AF);
  static const gray500 = Color(0xFF6B7280);
  static const gray600 = Color(0xFF4B5563);
  static const gray700 = Color(0xFF374151);
  static const gray800 = Color(0xFF1F2937);
  static const gray900 = Color(0xFF111827);
  static const gray950 = Color(0xFF030712);

  static const blue100 = Color(0xFFDBEAFE);
  static const blue200 = Color(0xFFBFDBFE);
  static const blue400 = Color(0xFF60A5FA);
  static const blue500 = Color(0xFF3B82F6);
  static const blue600 = Color(0xFF2563EB);

  static const emerald50 = Color(0xFFECFDF5);
  static const emerald200 = Color(0xFFA7F3D0);
  static const emerald500 = Color(0xFF10B981);
  static const emerald600 = Color(0xFF059669);

  static const orange300 = Color(0xFFFDBA74);
  static const orange400 = Color(0xFFFB923C);
  static const orange500 = Color(0xFFF97316);

  static const red50 = Color(0xFFFEF2F2);
  static const red200 = Color(0xFFFECACA);
  static const red500 = Color(0xFFEF4444);
  static const red600 = Color(0xFFDC2626);

  static const purple600 = Color(0xFF9333EA);

  static const streamColors = [
    Color(0xFF3B82F6),
    Color(0xFFEF4444),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF06B6D4),
    Color(0xFFF97316),
  ];
}

abstract final class AppTypography {
  static const sectionTitle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.gray800,
    letterSpacing: 0.2,
    height: 1.3,
  );

  static const body = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.gray800,
    letterSpacing: 0,
    height: 1.35,
  );

  static const bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.gray700,
    letterSpacing: 0,
    height: 1.35,
  );

  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.gray600,
    letterSpacing: 0,
    height: 1.3,
  );

  static const mono = TextStyle(
    fontFamily: 'Consolas',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.gray700,
    letterSpacing: 0,
    height: 1.3,
  );

  static const monoSmall = TextStyle(
    fontFamily: 'Consolas',
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.gray700,
    letterSpacing: 0,
    height: 1.3,
  );
}

TextTheme _buildTextTheme() {
  return const TextTheme(
    displayLarge: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: AppColors.gray900,
      letterSpacing: 0,
      height: 1.3,
    ),
    titleLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AppColors.gray900,
      letterSpacing: 0,
      height: 1.35,
    ),
    titleMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppColors.gray800,
      letterSpacing: 0,
      height: 1.35,
    ),
    titleSmall: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppColors.gray800,
      letterSpacing: 0,
      height: 1.35,
    ),
    bodyLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: AppColors.gray800,
      letterSpacing: 0,
      height: 1.4,
    ),
    bodyMedium: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: AppColors.gray800,
      letterSpacing: 0,
      height: 1.4,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: AppColors.gray700,
      letterSpacing: 0,
      height: 1.35,
    ),
    labelLarge: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppColors.gray800,
      letterSpacing: 0,
      height: 1.3,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppColors.gray800,
      letterSpacing: 0,
      height: 1.3,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: AppColors.gray700,
      letterSpacing: 0,
      height: 1.3,
    ),
  );
}

ThemeData buildAppTheme() {
  final textTheme = _buildTextTheme();

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.blue500,
      brightness: Brightness.light,
    ),
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.gray200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.gray200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.blue500, width: 2),
      ),
      hintStyle: AppTypography.caption.copyWith(color: AppColors.gray500),
      labelStyle: AppTypography.bodySmall,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      titleTextStyle: textTheme.titleMedium,
      contentTextStyle: textTheme.bodyMedium,
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.gray200),
      ),
    ),
    sliderTheme: const SliderThemeData(
      overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
    ),
  );
}
