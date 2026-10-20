import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../l10n/service_message_localizer.dart';
import '../logging/app_debug_log.dart';
import '../models/share_export_style.dart';
import '../utils/app_toast.dart';
import 'image_export_capture.dart';

/// 把课表渲染成一张干净的图片并拉起系统分享面板。
///
/// 出图顺序：**光栅化调用方给的文档** → 落临时文件 → 系统分享面板。中间那段
/// 是全屏转圈遮罩，用户看不到文档本身。
///
/// **文档由调用方（屏层）构造**，这里只收一个已经拼好的 [Widget]。原来是本
/// 服务自己 `TimetableExportDocument(provider: provider, ...)` 现拼，为此拖进
/// 三条反向依赖（`providers/`、`ui/`、`widgets/` 各一条）——而本服务对
/// `TimetableProvider` **零成员访问**，只是原样转手。谁拼文档、谁付依赖：
/// 屏层本来就在合法的上层，`timetable_screen.dart` 自己知道当前是哪一周、
/// 周视图还是日视图。
abstract final class TimetableShareService {
  /// 导出图的逻辑宽度区间。
  ///
  /// 比统计长图（320~420）略宽：课表是**七列**网格，宽度直接换成每列能放下
  /// 几个字；页边距与白卡内边距又会吃掉五十多个逻辑像素，太窄会把课程名
  /// 挤成省略号。上限仍留在手机量级，保证导出的图看着还是「一张手机课表」。
  static const double _minExportWidth = 360;
  static const double _maxExportWidth = 460;

  /// 渲染并分享调用方组装好的课表文档。
  static Future<void> exportAndShare({
    required BuildContext context,
    required Widget document,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final overlayState = Overlay.maybeOf(context, rootOverlay: true);
    if (overlayState == null) {
      appDebugLog('TimetableShare', 'Overlay not found for export capture');
      _toastFailure(context, l10n, 'overlay_missing');
      return;
    }

    try {
      final mediaQuery = MediaQuery.of(context);
      final pngBytes = await ImageExportCapture.captureToPng(
        overlayState: overlayState,
        mediaQuery: mediaQuery,
        theme: ImageExportCapture.lightExportThemeOf(context),
        textDirection: Directionality.of(context),
        exportWidth: mediaQuery.size.width.clamp(
          _minExportWidth,
          _maxExportWidth,
        ),
        scaffoldColor: ShareExportStyle.background,
        document: document,
        debugLabel: 'TimetableShare',
      );
      if (pngBytes == null) {
        appDebugLog('TimetableShare', 'Export capture returned empty bytes');
        if (context.mounted) {
          _toastFailure(context, l10n, 'capture_empty');
        }
        return;
      }

      final tempDirectory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputFile = File(
        '${tempDirectory.path}/timetable_share_$timestamp.png',
      );
      await outputFile.writeAsBytes(pngBytes, flush: true);

      if (!context.mounted) {
        return;
      }

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(outputFile.path, mimeType: 'image/png')],
          text: l10n.timetableShareText,
        ),
      );
    } catch (error, stackTrace) {
      appDebugLog('TimetableShare', 'Export failed: $error\n$stackTrace');
      if (context.mounted) {
        _toastFailure(context, l10n, '$error');
      }
    }
  }

  /// 失败提示。[context] 的 mounted 检查留在调用点（linter 只认眼皮底下的
  /// 那个 `if`），这里不再重复判断。
  static void _toastFailure(
    BuildContext context,
    AppLocalizations l10n,
    String detail,
  ) {
    showAppToast(
      context,
      message: localizeServiceMessage(
        l10n,
        encodeServiceMessage('timetable_share_failed', {'detail': detail}),
      ),
      kind: AppToastKind.error,
    );
  }
}
