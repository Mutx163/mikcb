import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../services/bundled_assets.dart';

/// Boot branding: centered launcher icon on the splash background.
///
/// Matches the Android 12+ system splash exactly (108dp centered icon on
/// splash_background colour) so the handoff is visually seamless — the user
/// sees one consistent splash, then the app content.

/// Returns a positive cache dimension or null (0/negative → no constraint).
int? _positiveCacheDimension(int? value) =>
    (value != null && value > 0) ? value : null;

class AppBootBranding extends StatefulWidget {
  const AppBootBranding({
    super.key,
    required this.appLabel,
    required this.isDark,
  });

  final String appLabel;
  final bool isDark;

  /// Matches the Android 12 system splash default icon size (108dp).
  static const double iconSize = 108;

  /// Splash / scaffold fill used while branding is on screen.
  static Color backgroundColor({required bool isDark}) {
    // Keep the first Flutter frame identical to Android's native splash colors
    // (res/values/colors.xml and res/values-night/colors.xml).
    return isDark ? const Color(0xFF121212) : const Color(0xFFFFFFFF);
  }

  /// Flavor-aware label: 正式 / 调试版 / 性能版.
  static String resolveAppLabel(
    PackageInfo packageInfo,
    AppLocalizations l10n,
  ) {
    if (packageInfo.packageName.endsWith('.profile')) {
      return l10n.appTitleProfile;
    }
    if (packageInfo.packageName.endsWith('.debug')) {
      return l10n.appTitleDebug;
    }
    final label = packageInfo.appName.trim();
    return label.isNotEmpty ? label : l10n.appTitle;
  }

  @override
  State<AppBootBranding> createState() => _AppBootBrandingState();
}

class _AppBootBrandingState extends State<AppBootBranding> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _resolveIcon();
  }

  Future<void> _resolveIcon() async {
    // Fast path: already in the global warm-up cache.
    final cached = BundledAssets.bytesFor(BundledAssets.launcherIcon);
    if (cached != null) {
      // The icon was prewarmed before runApp; assign synchronously so the
      // first Flutter branding frame already contains the real bitmap.
      _bytes = cached;
      return;
    }
    // Slow path: warm-up hasn't completed yet; load independently so the icon
    // swaps in from the Material placeholder as soon as bytes are available.
    try {
      final data = await rootBundle.load(BundledAssets.launcherIcon);
      if (!mounted) return;
      final bytes = data.buffer.asUint8List();
      // Store into the global cache so other widgets benefit too.
      BundledAssets.remember(BundledAssets.launcherIcon, bytes);
      if (mounted) setState(() => _bytes = bytes);
    } catch (_) {
      // Non-critical: the placeholder Icon stays visible.
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.isDark
        ? const Color(0xE6FFFFFF)
        : const Color(0xE6000000);

    // Show ONLY the centered icon — no text label. This matches the Android
    // 12+ system splash (which also shows just the icon), so the handoff from
    // system splash → Flutter branding is visually seamless: same icon,
    // same position, same background. The app name is not needed here because
    // it already appears in the app's TopAppBar once content loads.
    final iconWidget = _bytes != null
        ? SizedBox(
            width: AppBootBranding.iconSize,
            height: AppBootBranding.iconSize,
            child: Image.memory(
              _bytes!,
              width: AppBootBranding.iconSize,
              height: AppBootBranding.iconSize,
              // The PNG already has transparent rounded corners built in
              // (generate_app_icons.py applies a rounded_rect_mask), so we
              // use contain instead of cover and skip ClipRRect — this
              // matches the system splash which shows the raw icon shape.
              fit: BoxFit.contain,
              cacheWidth: _positiveCacheDimension(
                BundledAssets.bootLauncherIconCacheWidth,
              ),
              cacheHeight: _positiveCacheDimension(
                BundledAssets.bootLauncherIconCacheHeight,
              ),
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
            ),
          )
        : Icon(
            Icons.calendar_month_rounded,
            size: AppBootBranding.iconSize,
            color: iconColor,
          );

    return Center(child: iconWidget);
  }
}
