import 'package:flutter/material.dart';

/// Body/UI font: squared, slightly extended letterforms that echo the logo.
const appFontFamily = 'Saira Semi Expanded';

/// Display font for headings and big numbers: wide, geometric, close to the
/// Molenstraat wordmark. Ships in a single weight (400), so never bold it.
const appDisplayFontFamily = 'Michroma';

abstract final class AppColors {
  // Monochrome palette. `cyan` and `lime` are kept as names for the two
  // accent roles (idle / active) but are now black and dark grey.
  static const background = Color(0xffffffff);
  static const surface = Color(0xffffffff);
  static const surfaceRaised = Color(0xfff2f2f2);
  static const border = Color(0xffd6d6d6);
  static const text = Color(0xff000000);
  static const muted = Color(0xff5c5c5c);
  static const cyan = Color(0xff000000);
  static const lime = Color(0xff333333);
  static const error = Color(0xffb3261e);
  static const selected = Color(0xffe6e6e6);
}

ThemeData buildWorktimeTheme() {
  const fontFamily = appFontFamily;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.cyan,
        brightness: Brightness.light,
        dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
      ).copyWith(
        primary: AppColors.cyan,
        onPrimary: Colors.white,
        primaryContainer: AppColors.selected,
        onPrimaryContainer: AppColors.text,
        secondary: AppColors.lime,
        onSecondary: Colors.white,
        secondaryContainer: AppColors.selected,
        onSecondaryContainer: AppColors.text,
        tertiary: AppColors.lime,
        onTertiary: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.text,
        onSurfaceVariant: AppColors.muted,
        surfaceContainerHighest: AppColors.surfaceRaised,
        outline: AppColors.border,
        outlineVariant: AppColors.border,
        error: AppColors.error,
        onError: Colors.white,
      );
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    fontFamily: fontFamily,
    scaffoldBackgroundColor: AppColors.background,
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
  TextStyle? display(TextStyle? style, {double? size}) => style?.copyWith(
    fontFamily: appDisplayFontFamily,
    fontWeight: FontWeight.w400,
    fontSize: size,
    letterSpacing: 0.2,
    color: AppColors.text,
  );
  const rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(8)),
  );
  const fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(8)),
    borderSide: BorderSide(color: AppColors.border),
  );

  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      displayLarge: display(base.textTheme.displayLarge),
      displayMedium: display(base.textTheme.displayMedium),
      displaySmall: display(base.textTheme.displaySmall),
      headlineLarge: display(base.textTheme.headlineLarge),
      headlineMedium: display(base.textTheme.headlineMedium),
      headlineSmall: display(base.textTheme.headlineSmall, size: 18),
      titleLarge: display(base.textTheme.titleLarge, size: 16),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.45),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    ),
    appBarTheme: const AppBarThemeData(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        side: BorderSide(color: AppColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: AppColors.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      labelStyle: const TextStyle(color: AppColors.muted),
      floatingLabelStyle: const TextStyle(color: AppColors.text),
      hintStyle: TextStyle(color: AppColors.muted.withValues(alpha: 0.7)),
      border: fieldBorder,
      enabledBorder: fieldBorder,
      disabledBorder: fieldBorder.copyWith(
        borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      focusedBorder: fieldBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.text, width: 1.5),
      ),
      errorBorder: fieldBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: fieldBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.text,
      secondarySelectedColor: AppColors.text,
      disabledColor: AppColors.surfaceRaised,
      side: const BorderSide(color: AppColors.border),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
      labelStyle: TextStyle(
        fontFamily: fontFamily,
        color: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : states.contains(WidgetState.disabled)
              ? AppColors.muted.withValues(alpha: 0.6)
              : AppColors.text,
        ),
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      secondaryLabelStyle: TextStyle(
        fontFamily: fontFamily,
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      checkmarkColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      elevation: 0,
      pressElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: rounded,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.text),
        shape: rounded,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.text,
        shape: rounded,
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: AppColors.muted),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        side: BorderSide(color: AppColors.border),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: AppColors.surface,
      dragHandleColor: AppColors.border,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        side: BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.text,
      contentTextStyle: TextStyle(fontFamily: fontFamily, color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: rounded,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.text,
      linearTrackColor: AppColors.surfaceRaised,
      circularTrackColor: AppColors.surfaceRaised,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 60,
      indicatorColor: AppColors.text,
      indicatorShape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 22,
          color: states.contains(WidgetState.selected)
              ? Colors.white
              : AppColors.muted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: fontFamily,
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? AppColors.text
              : AppColors.muted,
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
    listTileTheme: const ListTileThemeData(
      textColor: AppColors.text,
      iconColor: AppColors.muted,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.text,
      selectionColor: AppColors.text.withValues(alpha: 0.2),
      selectionHandleColor: AppColors.text,
    ),
  );
}

class AppPanel extends StatelessWidget {
  const AppPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.margin = const EdgeInsets.only(bottom: 10),
    this.accent,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? accent;

  @override
  Widget build(BuildContext context) => Container(
    margin: margin,
    padding: padding,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: accent ?? AppColors.border),
    ),
    child: child,
  );
}

class WorktimeBackground extends StatelessWidget {
  const WorktimeBackground({
    super.key,
    required this.child,
    this.showGrid = false,
  });

  final Widget child;
  final bool showGrid;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.background,
    child: showGrid
        ? CustomPaint(painter: const _GridPainter(), child: child)
        : child,
  );
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = AppColors.text.withValues(alpha: 0.04)
      ..strokeWidth = 0.6;
    const step = 42.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}
