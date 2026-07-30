import 'package:flutter/material.dart';

/// Temporary compatibility widget until all FHeaderAction usages are
/// migrated to HyperosIconButton.
class FHeaderAction extends StatelessWidget {
  const FHeaderAction({
    super.key,
    required this.icon,
    required this.semanticsLabel,
    this.onPress,
  });

  final Widget icon;
  final String semanticsLabel;
  final VoidCallback? onPress;

  @override
  Widget build(BuildContext context) {
    // Pass the caller's widget through untouched: rebuilding `Icon(iconData)`
    // dropped the Icon's explicit color/size (e.g. the couple-mode pink heart
    // and the wallpaper chrome foreground on the home header).
    return Semantics(
      label: semanticsLabel,
      button: true,
      child: IconButton(
        icon: icon,
        onPressed: onPress,
        tooltip: semanticsLabel,
      ),
    );
  }
}

// ── Temporary Forui compatibility layer ──────────────────────────────────────

/// Type aliases so files that reference FColors / FTypography still compile.
typedef FColors = ForuiCompatColors;
typedef FTypography = ForuiCompatTypography;

/// Replaces Forui's `context.theme` — returns a [ForuiCompatTheme] object
/// that exposes `.colors` and `.typography` with the same property names.
extension ForuiCompatContext on BuildContext {
  ForuiCompatTheme get theme => ForuiCompatTheme._(this);
}

/// Stand-in for Forui's `FThemeData`.  Exposes `.colors` and `.typography`
/// backed by Material [ThemeData].
class ForuiCompatTheme {
  ForuiCompatTheme._(this._context);

  final BuildContext _context;
  late final ThemeData _t = Theme.of(_context);

  ForuiCompatColors get colors => ForuiCompatColors._(_t);
  ForuiCompatTypography get typography => ForuiCompatTypography._(_t);
}

/// Stand-in for Forui's `FColors`.
class ForuiCompatColors {
  ForuiCompatColors._(this._t);

  final ThemeData _t;

  Color get foreground => _t.colorScheme.onSurface;
  Color get mutedForeground => _t.colorScheme.onSurfaceVariant;
  Color get border => _t.dividerColor;
  Color get muted => _t.colorScheme.onSurface.withValues(alpha: 0.6);
  Color get primary => _t.colorScheme.primary;
  Color get secondary => _t.colorScheme.secondary;
  Color get background => _t.colorScheme.surface;
  Color get destructive => _t.colorScheme.error;
  Color get primaryForeground => _t.colorScheme.onPrimary;
}

/// Stand-in for Forui's `FTypography`.  Returns Material [TextStyle]s that
/// approximate the Forui typography scale.
class ForuiCompatTypography {
  ForuiCompatTypography._(this._t);

  final ThemeData _t;

  ForuiCompatTypeface get body => ForuiCompatTypeface._(_t.textTheme);
  ForuiCompatTypeface get display => ForuiCompatTypeface._(_t.textTheme);
}

class ForuiCompatTypeface {
  ForuiCompatTypeface._(this._tt);

  final TextTheme _tt;

  TextStyle get xs => _tt.bodySmall?.copyWith(fontSize: 12) ?? const TextStyle(fontSize: 12);
  TextStyle get xs2 => _tt.bodySmall?.copyWith(fontSize: 11) ?? const TextStyle(fontSize: 11);
  TextStyle get sm =>
      _tt.bodySmall?.copyWith(fontSize: 14) ?? const TextStyle(fontSize: 14);
  TextStyle get md => _tt.bodyMedium ?? const TextStyle();
  TextStyle get lg => _tt.bodyLarge ?? const TextStyle();
  TextStyle get xl => _tt.headlineSmall ?? const TextStyle();
  TextStyle get xl2 => _tt.headlineMedium ?? const TextStyle();

  ForuiCompatTypeface copyWith({
    TextStyle? xs,
    TextStyle? xs2,
    TextStyle? sm,
    TextStyle? md,
    TextStyle? lg,
    TextStyle? xl,
    TextStyle? xl2,
  }) {
    return this;
  } // simplified — not needed for compilation
}
