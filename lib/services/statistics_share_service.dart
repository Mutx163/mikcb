import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../l10n/service_message_localizer.dart';
import '../logging/app_debug_log.dart';
import '../models/statistics_export_options.dart';
import '../models/statistics_models.dart';
import '../ui/hyperos/hyperos_tokens.dart';
import '../utils/app_toast.dart';
import '../widgets/statistics/statistics_export_document.dart';
import 'image_export_capture.dart';

/// 把课程统计渲染成长图 PNG 并拉起系统分享面板。
///
/// 离屏捕获的机制本体在 [ImageExportCapture]（与课表图片分享共用）；
/// 这里只管三件事：拼文档、落临时文件、拉起分享。
class StatisticsShareService {
  StatisticsShareService._();

  /// 分享图恒用亮色底：透明孔洞在被分享出去后不会变成黑块。
  static const Color _exportScaffoldColor = HyperosTokens.background;

  static Future<void> exportAndShare({
    required BuildContext context,
    required StatisticsExportOptions options,
    required SemesterStats semesterStats,
    required List<Achievement> achievements,
    required List<DataStory> stories,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    if (!options.hasModules) {
      if (context.mounted) {
        showAppToast(
          context,
          message: l10n.statisticsExportSelectModuleHint,
          kind: AppToastKind.warning,
        );
      }
      return;
    }

    final overlayState = Overlay.maybeOf(context, rootOverlay: true);
    if (overlayState == null) {
      appDebugLog('StatisticsShare', 'Overlay not found for export capture');
      if (context.mounted) {
        showAppToast(
          context,
          message: localizeServiceMessage(
            l10n,
            encodeServiceMessage('statistics_share_failed', {
              'detail': 'overlay_missing',
            }),
          ),
          kind: AppToastKind.error,
        );
      }
      return;
    }

    try {
      final mediaQuery = MediaQuery.of(context);
      final pngBytes = await ImageExportCapture.captureToPng(
        overlayState: overlayState,
        mediaQuery: mediaQuery,
        theme: ImageExportCapture.lightExportThemeOf(context),
        textDirection: Directionality.of(context),
        exportWidth: mediaQuery.size.width.clamp(320.0, 420.0),
        scaffoldColor: _exportScaffoldColor,
        document: StatisticsExportDocument(
          options: options,
          semesterStats: semesterStats,
          achievements: achievements,
          stories: stories,
        ),
        debugLabel: 'StatisticsShare',
      );
      if (pngBytes == null) {
        appDebugLog('StatisticsShare', 'Export capture returned empty bytes');
        if (context.mounted) {
          showAppToast(
            context,
            message: localizeServiceMessage(
              l10n,
              encodeServiceMessage('statistics_share_failed', {
                'detail': 'capture_empty',
              }),
            ),
            kind: AppToastKind.error,
          );
        }
        return;
      }

      final tempDirectory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputFile = File(
        '${tempDirectory.path}/statistics_export_$timestamp.png',
      );
      await outputFile.writeAsBytes(pngBytes, flush: true);

      if (!context.mounted) {
        return;
      }

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(outputFile.path, mimeType: 'image/png')],
          subject: l10n.statisticsShareTitle,
          text: l10n.statisticsShareText,
        ),
      );
    } catch (error, stackTrace) {
      appDebugLog('StatisticsShare', 'Export failed: $error\n$stackTrace');
      if (context.mounted) {
        showAppToast(
          context,
          message: localizeServiceMessage(
            AppLocalizations.of(context)!,
            encodeServiceMessage('statistics_share_failed', {
              'detail': '$error',
            }),
          ),
          kind: AppToastKind.error,
        );
      }
    }
  }
}
