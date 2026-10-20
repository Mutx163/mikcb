import 'package:flutter/material.dart';

import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../services/timetable_share_service.dart';
import 'timetable_export_document.dart';

/// 课表分享图：**在界面层组装导出文档**，再交给分享服务光栅化。
///
/// 为什么要有这一层：
/// * `TimetableExportDocument` 住在 `widgets/`，并且要 `TimetableProvider` 与
///   当前周次才能拼出来 —— 这些都是界面层的东西；
/// * `TimetableShareService`（`services/`）只该管「光栅化 + 落文件 + 拉起分享」。
///   它原先自己拼文档，为此拖进三条反向依赖（`providers/` / `ui/` / `widgets/`
///   各一条），而它对该 Provider **零成员访问**，纯属原样转手。
///
/// 两个入口共用这一份组装，避免「同一个分享功能被拼成两张不同的图」：
/// * 课表页拦截菜单时（只有它知道当前可见周、周视图还是日视图）；
/// * 八宫格 / 玻璃坞从别的页面点进来时的兜底（分享本周周视图）。
///
/// 住 `widgets/` 而不是屏层：兜底入口本身就在 `widgets/`（`home_menu_catalog`），
/// 而 `widgets → screens` 是反向依赖。`widgets → providers` / `widgets → services`
/// 都在层序允许的方向内。
///
/// [timetableShareDocument] 单独拆出来是为了**可测**：文档有没有拿到调用方给的
/// 那几个参数（尤其 `dayOfWeek` 丢失会静默变成分享整周），只能靠直接断言文档
/// 实例字段来钉，见 `test/services/share_export_document_contract_test.dart`。
TimetableExportDocument timetableShareDocument({
  required TimetableProvider provider,
  required TimetableSettings settings,
  required int week,
  int? dayOfWeek,
}) {
  return TimetableExportDocument(
    provider: provider,
    settings: settings,
    week: week,
    dayOfWeek: dayOfWeek,
  );
}

/// 组装文档并分享（[dayOfWeek] 非空时只分享那一天）。
Future<void> shareTimetableImage({
  required BuildContext context,
  required TimetableProvider provider,
  required TimetableSettings settings,
  required int week,
  int? dayOfWeek,
}) {
  return TimetableShareService.exportAndShare(
    context: context,
    document: timetableShareDocument(
      provider: provider,
      settings: settings,
      week: week,
      dayOfWeek: dayOfWeek,
    ),
  );
}
