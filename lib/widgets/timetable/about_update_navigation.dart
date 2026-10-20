import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../ui/hyperos/hyperos.dart';
import 'timetable_form_pages.dart';

/// 打开「关于/版本更新」页（2026-10-20 从更新控制器搬出）。
///
/// 导航属于 UI 层；控制器只负责版本检查/下载，不再 import screens。
///
/// 页面构造在 screens 层（经 [timetableFormPages.aboutUpdate] 注入）：
/// 「取包信息 → 判 mounted → 推页」这段时序留在这里（它是导航语义，不是
/// 页面构造），只有「造哪个页面」被抽走。
Future<void> openTimetableAboutUpdatePage(BuildContext context) async {
  final packageInfo = await PackageInfo.fromPlatform();
  if (!context.mounted) {
    return;
  }
  await Navigator.of(context).push<void>(
    HyperosPageRoute<void>(
      builder: (_) => timetableFormPages.aboutUpdate(packageInfo: packageInfo),
    ),
  );
}
