import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../services/bundled_assets.dart';
import '../ui/hyperos/hyperos_tokens.dart';

/// Shared boot branding: rounded launcher icon + flavor-aware app name.
///
/// Mirrors the native [SplashLayerDrawable] layout (96dp icon, 16dp gap, 20sp
/// medium label) so the handoff from the system splash feels continuous.

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

  static const double iconSize = 96;
  static const double iconCornerRadius = 22;
  static const double labelGap = 16;

  /// Splash / scaffold fill used while branding is on screen.
  static Color backgroundColor({required bool isDark}) {
    return isDark ? HyperosTokens.primaryText : HyperosTokens.card;
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
      if (mounted) setState(() => _bytes = cached);
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
    final labelColor = widget.isDark
        ? const Color(0xE6FFFFFF)
        : const Color(0xE6000000);

    // First frame: _bytes is null → Material calendar icon (synchronous, same
    // frame as the text).  After _resolveIcon completes: _bytes is set → the
    // real launcher icon swaps in via setState without any flash.
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
            color: labelColor,
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
              color: labelColor,
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
