import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../l10n/service_message_localizer.dart';
import '../logging/app_debug_log.dart';
import '../models/share_export_style.dart';
import '../models/statistics_export_options.dart';
import '../utils/app_toast.dart';
import 'image_export_capture.dart';

/// 把课程统计渲染成长图 PNG 并拉起系统分享面板。
///
/// 离屏捕获的机制本体在 [ImageExportCapture]（与课表图片分享共用）；
/// 这里只管三件事：**光栅化调用方给的文档**、落临时文件、拉起分享。
///
/// **文档由调用方（屏层）构造**，这里只收一个已经拼好的 [Widget]。理由有二：
/// * 服务层不该认识界面层 —— `StatisticsExportDocument` 住在 `widgets/`，
///   服务 import 它是反向依赖；
/// * 「分享图长什么样」本来就是界面层的事，文档类型以后要换（比如加模块）
///   不该牵动分享管线。
class StatisticsShareService {
  StatisticsShareService._();

  static Future<void> exportAndShare({
    required BuildContext context,
    required StatisticsExportOptions options,
    required Widget document,
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
        scaffoldColor: ShareExportStyle.background,
        document: document,
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
