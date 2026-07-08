import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../logging/app_debug_log.dart';
import '../l10n/service_message_localizer.dart';
import '../utils/app_toast.dart';

/// 统计分享服务
class StatisticsShareService {
  StatisticsShareService._();

  /// 将 Widget 截图为图片并分享
  static Future<void> shareWidgetAsImage({
    required BuildContext context,
    required GlobalKey repaintBoundaryKey,
    required String title,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      // 1. 找到 RenderRepaintBoundary
      final boundary =
          repaintBoundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        appDebugLog('StatisticsShare', 'RepaintBoundary not found');
        return;
      }

      // 2. 截图为图片
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        appDebugLog('StatisticsShare', 'Failed to convert image to bytes');
        return;
      }

      // 3. 保存到临时文件
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/statistics_share.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      // 4. 分享
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: title,
          text: l10n.statisticsShareText,
        ),
      );
    } catch (e) {
      appDebugLog('StatisticsShare', 'Share failed: $e');
      if (context.mounted) {
        showAppToast(
          context,
          message: localizeServiceMessage(
            AppLocalizations.of(context)!,
            encodeServiceMessage(
              'statistics_share_failed',
              {'detail': '$e'},
            ),
          ),
          kind: AppToastKind.error,
        );
      }
    }
  }
}
