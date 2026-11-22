import 'package:flutter/material.dart';

/// Estilos compartidos de los diálogos Foody en claro y oscuro.
class FoodyDialogo {
  FoodyDialogo._();

  static ThemeData tema(BuildContext context) {
    final base = Theme.of(context);
    final scheme = base.colorScheme;
    final borde = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: scheme.outlineVariant),
    );
    return base.copyWith(
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(
          height: 1.35,
          color: scheme.onSurfaceVariant,
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        border: borde,
        enabledBorder: borde,
        focusedBorder: borde.copyWith(
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
    );
  }

  static Future<T?> mostrar<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: const Color(0xFF111827).withValues(alpha: 0.45),
      animationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : const AnimationStyle(
              duration: Duration(milliseconds: 200),
              reverseDuration: Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
            ),
      builder: (ctx) => Theme(
        data: tema(ctx),
        child: Builder(builder: builder),
      ),
    );
  }
}
