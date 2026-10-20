import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../screens/about_screen.dart';
import '../../ui/hyperos/hyperos.dart';

/// 打开「关于/版本更新」页（2026-10-20 从更新控制器搬出）。
///
/// 导航属于 UI 层；控制器只负责版本检查/下载，不再 import screens。
Future<void> openTimetableAboutUpdatePage(BuildContext context) async {
  final packageInfo = await PackageInfo.fromPlatform();
  if (!context.mounted) {
    return;
  }
  await Navigator.of(context).push<void>(
    HyperosPageRoute<void>(
      builder: (_) => AboutUpdateScreen(packageInfo: packageInfo),
    ),
  );
}
