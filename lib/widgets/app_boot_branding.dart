import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../services/bundled_assets.dart';
import '../ui/hyperos/hyperos_tokens.dart';
import 'bundled_asset_image.dart';

/// Shared boot branding: rounded launcher icon + flavor-aware app name.
///
/// Mirrors the native [SplashLayerDrawable] layout (96dp icon, 16dp gap, 20sp
/// medium label) so the handoff from the system splash feels continuous.
class AppBootBranding extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final labelColor = isDark
        ? const Color(0xE6FFFFFF)
        : const Color(0xE6000000);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(iconCornerRadius),
            child: SizedBox(
              width: iconSize,
              height: iconSize,
              child: BundledAssetImage(
                assetPath: BundledAssets.launcherIcon,
                width: iconSize,
                height: iconSize,
                fit: BoxFit.cover,
                cacheWidth: BundledAssets.bootLauncherIconCacheWidth,
                cacheHeight: BundledAssets.bootLauncherIconCacheHeight,
              ),
            ),
          ),
          const SizedBox(height: labelGap),
          Text(
            appLabel,
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
