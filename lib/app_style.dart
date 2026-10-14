import 'package:flutter/material.dart';

const appFontFamily = 'JetBrains Mono';

abstract final class AppColors {
  static const background = Color(0xfff7f8fa);
  static const surface = Color(0xffffffff);
  static const surfaceRaised = Color(0xfff0f4f2);
  static const border = Color(0xffdce2de);
  static const text = Color(0xff202923);
  static const muted = Color(0xff58675f);
  static const cyan = Color(0xff226b62);
  static const lime = Color(0xff486b29);
  static const error = Color(0xffb3261e);

  static const backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xfff7faf8), background, Color(0xfff3f7f5)],
  );
}

ThemeData buildWorktimeTheme() {
  const fontFamily = appFontFamily;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.cyan,
        brightness: Brightness.light,
      ).copyWith(
        primary: AppColors.cyan,
        onPrimary: Colors.white,
        primaryContainer: const Color(0xffd3ece5),
        onPrimaryContainer: AppColors.cyan,
        secondary: AppColors.lime,
        onSecondary: Colors.white,
        secondaryContainer: const Color(0xffe2edcf),
        onSecondaryContainer: AppColors.lime,
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
  );
  const rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(14)),
  );
  const fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(14)),
    borderSide: BorderSide(color: AppColors.border),
  );

  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      displayLarge: base.textTheme.displayLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -2.4,
        color: AppColors.text,
      ),
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        color: AppColors.text,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
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
        borderRadius: BorderRadius.all(Radius.circular(24)),
        side: BorderSide(color: AppColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: AppColors.background.withValues(alpha: 0.58),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      labelStyle: const TextStyle(color: AppColors.muted),
      floatingLabelStyle: const TextStyle(color: AppColors.cyan),
      hintStyle: TextStyle(color: AppColors.muted.withValues(alpha: 0.7)),
      border: fieldBorder,
      enabledBorder: fieldBorder,
      disabledBorder: fieldBorder.copyWith(
        borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      focusedBorder: fieldBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.cyan, width: 1.5),
      ),
      errorBorder: fieldBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: fieldBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.background.withValues(alpha: 0.45),
      selectedColor: const Color(0xffd3ece5),
      secondarySelectedColor: const Color(0xffd3ece5),
      disabledColor: AppColors.background.withValues(alpha: 0.3),
      side: const BorderSide(color: AppColors.border),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(11)),
      ),
      labelStyle: TextStyle(
        fontFamily: fontFamily,
        color: AppColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      secondaryLabelStyle: TextStyle(
        fontFamily: fontFamily,
        color: AppColors.cyan,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      checkmarkColor: AppColors.cyan,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      elevation: 0,
      pressElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: rounded,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        textStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.cyan,
        side: const BorderSide(color: AppColors.border),
        shape: rounded,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.cyan,
        shape: rounded,
        minimumSize: const Size(0, 44),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: AppColors.muted),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(24)),
        side: BorderSide(color: AppColors.border),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: AppColors.surface,
      dragHandleColor: AppColors.border,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        side: BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceRaised,
      contentTextStyle: TextStyle(
        fontFamily: fontFamily,
        color: AppColors.text,
      ),
      behavior: SnackBarBehavior.floating,
      shape: rounded,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.lime,
      linearTrackColor: AppColors.surfaceRaised,
      circularTrackColor: AppColors.surfaceRaised,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
    listTileTheme: const ListTileThemeData(
      textColor: AppColors.text,
      iconColor: AppColors.muted,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.cyan,
      selectionColor: AppColors.cyan.withValues(alpha: 0.25),
      selectionHandleColor: AppColors.cyan,
    ),
  );
}

class AppPanel extends StatelessWidget {
  const AppPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.margin = const EdgeInsets.only(bottom: 16),
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
      borderRadius: BorderRadius.circular(24),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.surfaceRaised.withValues(alpha: 0.84),
          AppColors.surface.withValues(alpha: 0.94),
        ],
      ),
      border: Border.all(
        color: accent?.withValues(alpha: 0.3) ?? AppColors.border,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
        if (accent != null)
          BoxShadow(
            color: accent!.withValues(alpha: 0.035),
            blurRadius: 36,
            spreadRadius: 2,
          ),
      ],
    ),
    child: child,
  );
}

class WorktimeBackground extends StatelessWidget {
  const WorktimeBackground({
    super.key,
    required this.child,
    this.showGrid = true,
  });

  final Widget child;
  final bool showGrid;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
    child: CustomPaint(
      painter: _BackgroundPainter(showGrid: showGrid),
      child: child,
    ),
  );
}

class _BackgroundPainter extends CustomPainter {
  const _BackgroundPainter({required this.showGrid});

  final bool showGrid;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final glow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.9, -0.8),
        radius: 0.9,
        colors: [AppColors.cyan.withValues(alpha: 0.07), Colors.transparent],
      ).createShader(bounds);
    canvas.drawRect(bounds, glow);
    if (!showGrid) return;
    final grid = Paint()
      ..color = AppColors.muted.withValues(alpha: 0.035)
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
  bool shouldRepaint(_BackgroundPainter oldDelegate) =>
      showGrid != oldDelegate.showGrid;
}
