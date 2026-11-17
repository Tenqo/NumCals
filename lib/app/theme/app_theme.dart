import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';

ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final colorScheme = isDark
      ? const ColorScheme.dark(
          primary: AppColors.darkPrimary,
          onPrimary: Colors.white,
          surface: AppColors.darkSurface,
          onSurface: Colors.white,
          surfaceContainerHighest: AppColors.darkSurfaceContainer,
          onSurfaceVariant: AppColors.darkOnSurfaceVariant,
          error: AppColors.darkError,
        )
      : const ColorScheme.light(
          primary: AppColors.lightPrimary,
          onPrimary: Colors.white,
          surface: AppColors.lightSurface,
          onSurface: Color(0xFF28251F),
          surfaceContainerHighest: AppColors.lightSurfaceContainer,
          onSurfaceVariant: AppColors.lightOnSurfaceVariant,
          error: AppColors.lightError,
        );

  return ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: isDark ? Colors.black : AppColors.lightScaffold,
    colorScheme: colorScheme,
    useMaterial3: true,
  );
}
