import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../services/bundled_assets.dart';

/// Loading branding: launcher icon + app name on the splash background.
///
/// Used in two places:
/// 1. Boot overlay (main.dart): bridges the Android system splash and
///    the app content — same icon, same background, no blank screen.
/// 2. TimetableScreen loading state: shown while the provider reloads.

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

  /// Rounded-corner radius, matching splash_icon.png's built-in mask
  /// (154px on 717px → same ratio applied to 108dp).
  static const double iconCornerRadius = 23;

  /// Gap between icon and label.
  static const double labelGap = 16;

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

    // Icon size and position match the Android 12+ system splash exactly
    // (108dp centered) so the icon doesn't jump between system splash and
    // this page. The app name appears below, giving a complete brand look.
    final iconWidget = _bytes != null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(
              AppBootBranding.iconCornerRadius,
            ),
            child: SizedBox(
              width: AppBootBranding.iconSize,
              height: AppBootBranding.iconSize,
              child: Image.memory(
                _bytes!,
                width: AppBootBranding.iconSize,
                height: AppBootBranding.iconSize,
                fit: BoxFit.cover,
                cacheWidth: _positiveCacheDimension(
                  BundledAssets.bootLauncherIconCacheWidth,
                ),
                cacheHeight: _positiveCacheDimension(
                  BundledAssets.bootLauncherIconCacheHeight,
                ),
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
              ),
            ),
          )
        : Icon(
            Icons.calendar_month_rounded,
            size: AppBootBranding.iconSize,
            color: iconColor,
          );

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget,
          const SizedBox(height: AppBootBranding.labelGap),
          Text(
            widget.appLabel,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: iconColor,
              fontSize: 20,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
