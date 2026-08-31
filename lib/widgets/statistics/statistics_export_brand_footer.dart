import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../../models/statistics_export_options.dart';
import '../../services/bundled_assets.dart';
import '../bundled_asset_image.dart';

/// Brand strip for export-only captures (header and/or footer).
///
/// Left (top-aligned): logo.
/// Middle: name + tagline + website.
/// Right: website QR sized to the text block height (square).
///
/// Avoids [IntrinsicHeight] + [AspectRatio] around [QrImageView]: QR uses
/// [LayoutBuilder], which cannot participate in intrinsic measurements.
class StatisticsExportBrandBar extends StatelessWidget {
  const StatisticsExportBrandBar({
    super.key,
    this.showTopDivider = false,
    this.showBottomDivider = false,
  });

  factory StatisticsExportBrandBar.footer({Key? key}) {
    return StatisticsExportBrandBar(key: key, showTopDivider: true);
  }

  factory StatisticsExportBrandBar.header({Key? key}) {
    return StatisticsExportBrandBar(key: key, showBottomDivider: true);
  }

  final bool showTopDivider;
  final bool showBottomDivider;

  static const double _logoSize = 40;

  /// Approximate height of name + tagline + website (matches visual stack).
  static double _estimateTextBlockHeight(BuildContext context) {
    final titleStyle = HyperosTypography.listTitle(
      context,
    ).copyWith(fontWeight: FontWeight.w700, height: 1.1);
    final detailStyle = HyperosTypography.listDetail(
      context,
    ).copyWith(height: 1.15);
    final titleHeight =
        (titleStyle.fontSize ?? 17) * (titleStyle.height ?? 1.1);
    final detailHeight =
        (detailStyle.fontSize ?? 13) * (detailStyle.height ?? 1.15);
    // title + 1 gap + tagline + 2 gap + website
    return titleHeight + 1 + detailHeight + 2 + detailHeight;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final primaryText = HyperosColors.primaryText(context);
    final secondaryText = HyperosColors.secondaryText(context);
    final linkColor = HyperosColors.primary(context);
    final dividerColor = HyperosColors.dividerLine(
      context,
    ).withValues(alpha: 0.7);
    final linkStyle = HyperosTypography.listDetail(
      context,
    ).copyWith(color: linkColor, fontWeight: FontWeight.w600, height: 1.15);
    final qrSize = _estimateTextBlockHeight(context).clamp(48.0, 72.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showTopDivider) ...[
            Divider(height: 1, thickness: 1, color: dividerColor),
            const SizedBox(height: 10),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: const BundledAssetImage(
                  assetPath: BundledAssets.launcherIcon,
                  width: _logoSize,
                  height: _logoSize,
                  fit: BoxFit.cover,
                  cacheWidth: 168,
                  cacheHeight: 168,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.timetableAppName,
                      style: HyperosTypography.listTitle(context).copyWith(
                        color: primaryText,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      l10n.statisticsExportBrandTagline,
                      style: HyperosTypography.listDetail(
                        context,
                      ).copyWith(color: secondaryText, height: 1.15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      StatisticsExportBrand.websiteDisplay,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: linkStyle,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: qrSize,
                height: qrSize,
                child: const _WebsiteQrCode(),
              ),
            ],
          ),
          if (showBottomDivider) ...[
            const SizedBox(height: 10),
            Divider(height: 1, thickness: 1, color: dividerColor),
          ],
        ],
      ),
    );
  }
}

class _WebsiteQrCode extends StatelessWidget {
  const _WebsiteQrCode();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? Colors.white : const Color(0xFF111111);

    return QrImageView(
      data: StatisticsExportBrand.websiteUrl,
      padding: EdgeInsets.zero,
      eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: ink),
      dataModuleStyle: QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: ink,
      ),
    );
  }
}

typedef StatisticsExportBrandFooter = StatisticsExportBrandBar;
