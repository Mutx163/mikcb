// 本文件由 course_import_screen.dart 拆分而来（2026-10-06）。
// 首页下拉快捷导入
// 课表页下拉触发的后台仓库快捷导入（挂 Overlay 跑，不弹网页登录页）。
// 拆分只搬移代码、不改逻辑；符号可见性与 import 由拆分统一补齐。

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import '../../models/warehouse_macro_models.dart';
import '../../models/warehouse_repository_models.dart';
import '../../services/warehouse_import_preferences_service.dart';
import '../../services/warehouse_macro_service.dart';
import '../../utils/app_toast.dart';
import 'import_shared.dart';
import 'warehouse/warehouse_adapter_web_login_screen.dart';

/// 后台快捷导入的**整场**看门狗时长。
///
/// 为什么必须有整场这一层：整条链路（读宏 → 挂隐形网页 → 回放脚本 → 执行导入）
/// 每一段都有自己的超时，但**没有一段管得住整场**；任何一条没报回来的路都会让
/// 首页那颗药丸一直转下去（2026-09-22 真机：下拉的转圈一直显示、不消失）。
/// 到点一律按失败收尾 —— 摘 Overlay（平台视图与脚本一起停）并提示去手动跑一遍，
/// 走的还是"需要手动操作"那条既有出口。
///
/// 取值 120s：合法路径的最慢组合（页面就绪 20s + 单步轮询 15s + 执行导入 30s，
/// 见 `WarehouseMacroReplayer` 与 `_importTimeout`）之上再留一档余量；正常流程
/// 不会被它砍断。
const Duration _kHomePullQuickImportSessionTimeout = Duration(seconds: 120);

/// 写入阶段独立保护。正常写入远快于此；超过它说明底层存储或 provider
/// Future 已经失去响应，不能让首页永远转圈。
const Duration _kHomePullQuickImportWriteTimeout = Duration(minutes: 5);

/// Runs warehouse quick import without showing the WebView login page.
///
/// Equivalent to tapping the lightning icon on the warehouse import school list,
/// but keeps the browser off-screen for home pull-to-refresh.
///
/// Hosted in an [Overlay] (not a route) so the home page stays interactive.
/// Call [onCancelAvailable] with a cancel callback while the session is active.
Future<bool> runHomePullWarehouseQuickImport(
  BuildContext context, {
  VoidCallback? onNeedsManualAction,
  void Function(bool Function() cancel)? onCancelAvailable,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final macroService = WarehouseMacroService();
  final preferencesService = WarehouseImportPreferencesService();
  final completer = Completer<bool>();
  var sessionFinished = false;
  var cancelRequested = false;
  var importWriteStarted = false;
  OverlayEntry? overlayEntry;
  Timer? watchdog;
  Timer? writeWatchdog;

  void completeSession(bool success) {
    if (sessionFinished) {
      return;
    }
    sessionFinished = true;
    watchdog?.cancel();
    watchdog = null;
    writeWatchdog?.cancel();
    writeWatchdog = null;
    overlayEntry?.remove();
    overlayEntry = null;
    if (!completer.isCompleted) {
      completer.complete(success);
    }
  }

  bool requestCancel() {
    if (sessionFinished) {
      return true;
    }
    cancelRequested = true;
    // 已经进入实际写入阶段时不能假装取消成功；等导入回调报告真实结果。
    if (!importWriteStarted) {
      completeSession(false);
      return true;
    }
    return false;
  }

  // 从流程第一步就挂上取消和整场保护，避免读取本地宏记录时没有出口。
  onCancelAvailable?.call(requestCancel);

  void armSessionWatchdog() {
    if (sessionFinished) {
      return;
    }
    if (importWriteStarted) {
      watchdog?.cancel();
      watchdog = null;
      writeWatchdog?.cancel();
      writeWatchdog = Timer(_kHomePullQuickImportWriteTimeout, () {
        if (sessionFinished) {
          return;
        }
        cancelRequested = true;
        completeSession(false);
        onNeedsManualAction?.call();
      });
      return;
    }
    writeWatchdog?.cancel();
    writeWatchdog = null;
    watchdog?.cancel();
    watchdog = Timer(_kHomePullQuickImportSessionTimeout, () {
      if (sessionFinished) {
        return;
      }
      cancelRequested = true;
      completeSession(false);
      onNeedsManualAction?.call();
    });
  }

  armSessionWatchdog();

  Future<void> prepare() async {
    try {
      final allEntries = await macroService.getAllMacroEntries();
      if (!context.mounted || sessionFinished) {
        completeSession(false);
        return;
      }
      if (allEntries.isEmpty) {
        showAppLightTip(context, message: l10n.noSavedQuickImportRecords);
        completeSession(false);
        return;
      }

      WarehouseMacroRecord? macro;
      for (final entry in allEntries) {
        final record = await macroService.getMacro(
          entry.schoolId,
          entry.adapterId,
        );
        if (record != null) {
          macro = record;
          break;
        }
      }
      if (!context.mounted || sessionFinished) {
        completeSession(false);
        return;
      }
      if (macro == null) {
        showAppLightTip(context, message: l10n.noSavedQuickImportRecords);
        completeSession(false);
        return;
      }

      final customUrl = await preferencesService.getCustomImportUrl(
        macro.adapterId,
      );
      if (!context.mounted || sessionFinished) {
        completeSession(false);
        return;
      }
      final initialUrl = resolveWarehouseImportUrl(
        customImportUrl: customUrl,
        defaultUrl: macro.importUrl,
      );
      if (!context.mounted || sessionFinished) {
        completeSession(false);
        return;
      }
      if (initialUrl == null) {
        showAppLightTip(context, message: l10n.noValidWarehouseLoginUrl);
        completeSession(false);
        return;
      }

      final fetchOptions = currentWarehouseFetchOptions(context);
      const source = defaultQingyuWarehouseSource;
      final selectedMacro = macro;

      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      if (overlay == null) {
        showAppLightTip(context, message: l10n.quickImportUnknownError);
        completeSession(false);
        return;
      }

      overlayEntry = OverlayEntry(
        builder: (overlayContext) {
          // Keep a tiny on-screen platform view so WebView keeps running, but do
          // not intercept home-page touches.
          return IgnorePointer(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 1,
                height: 1,
                child: WarehouseAdapterWebLoginScreen(
                  title: l10n.quickImportTitle(selectedMacro.schoolName),
                  initialUrl: initialUrl,
                  source: source,
                  school: WarehouseSchoolEntry(
                    id: selectedMacro.schoolId,
                    name: selectedMacro.schoolName,
                    initial: selectedMacro.schoolName.isNotEmpty
                        ? selectedMacro.schoolName[0]
                        : '#',
                    resourceFolder:
                        selectedMacro.schoolResourceFolder.isNotEmpty
                        ? selectedMacro.schoolResourceFolder
                        : selectedMacro.schoolId,
                  ),
                  adapter: WarehouseAdapterEntry(
                    adapterId: selectedMacro.adapterId,
                    adapterName: selectedMacro.adapterName,
                    category: 'macro',
                    assetJsPath: selectedMacro.adapterAssetJsPath.isNotEmpty
                        ? selectedMacro.adapterAssetJsPath
                        : 'macro/${selectedMacro.adapterId}.js',
                    importUrl: selectedMacro.importUrl,
                    maintainer: 'macro',
                    description: l10n.courseImportQuickImportDescription(
                      selectedMacro.schoolName,
                      selectedMacro.adapterName,
                    ),
                  ),
                  fetchOptions: fetchOptions,
                  macroRecord: selectedMacro,
                  runInBackground: true,
                  onBackgroundNeedsManualAction: onNeedsManualAction,
                  onBackgroundFinished: completeSession,
                  onBackgroundProgress: armSessionWatchdog,
                  isBackgroundImportCancelled: () => cancelRequested,
                  onBackgroundImportStarted: () {
                    if (importWriteStarted || sessionFinished) {
                      return;
                    }
                    importWriteStarted = true;
                    armSessionWatchdog();
                  },
                ),
              ),
            ),
          );
        },
      );

      overlay.insert(overlayEntry!);
    } catch (_) {
      if (sessionFinished) {
        return;
      }
      cancelRequested = true;
      completeSession(false);
      onNeedsManualAction?.call();
    }
  }

  unawaited(prepare());
  return completer.future;
}


