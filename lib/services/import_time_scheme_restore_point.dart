import 'package:flutter/foundation.dart';

import '../models/time_scheme.dart';
import '../models/timetable_settings.dart';
import 'timetable_import_export_service.dart';

/// 恢复点需要的课表宿主窄面（端口由消费方定义）。
///
/// 本文件在 services 层，不反向 import `providers/timetable_provider.dart`：
/// 恢复动作只需要「读设置快照 / 活读作息表 / 写回整份设置 / 删作息模板」
/// 四个成员。宿主适配器 `ImportRestoreProviderAccess` 见
/// `lib/providers/import_restore_provider_access.dart`，由调用点（四个导入
/// 屏、测试）构造注入。成员一律一行转发，时序语义全部留在恢复点里。
abstract class ImportTimeSchemeRestoreHost {
  TimetableSettings get settings;

  List<TimeScheme> get timeSchemes;

  Future<String?> updateTimetableSettings(TimetableSettings settings);

  Future<bool> deleteTimeScheme(String schemeId);
}

/// 教务导入的作息恢复点（2026-10-08）。
///
/// 脚本下发的作息表在**课程写库之前**就被切/建成当前生效的那套
/// （`warehouse_adapter_web_login_screen` 的 `_applyImportedSections` →
/// `createTimeScheme(applyToActiveProfile: true)` / `applyTimeScheme`）。于是导入
/// 半途中止时（用户取消、容量弹窗返回 false、学期映射取消、写盘抛错、中途 unmount），
/// 用户的作息已经被换掉了 —— 他"什么都没干"，而重启后 `_ensureTimeSchemes` 还会
/// 照着盘上那份把节次对齐进各课表，变成永久的。
///
/// 为什么恢复整份 [TimetableSettings] 而不是只切回 schemeId：
/// 原本"没有启用任何模板"时 `activeTimeSchemeId` 就是 null，而
/// `TimetableSettings.copyWith` 的参数是 `?? this.activeTimeSchemeId`，清不掉它 ——
/// 只切 id 的话，一个本来没有模板的用户会被永久留在一个教务模板上。
class ImportTimeSchemeRestorePoint {
  ImportTimeSchemeRestorePoint._({
    required this.host,
    required this.settings,
    required this.schemeIds,
  });

  /// 记下"切作息之前"那一份设置。调用点必须在**应用教务作息之前**。
  factory ImportTimeSchemeRestorePoint.capture(
    ImportTimeSchemeRestoreHost host,
  ) => ImportTimeSchemeRestorePoint._(
    host: host,
    settings: host.settings,
    schemeIds: host.timeSchemes.map((scheme) => scheme.id).toSet(),
  );

  final ImportTimeSchemeRestoreHost host;
  final TimetableSettings settings;

  /// 捕获那一刻已存在的作息 id 集合。
  ///
  /// 为什么必须记它：导入的扩节路径在「多张课表共用同一套作息」时会**新建
  /// 一份副本**（`import_export_service.dart` 的 `（导入补齐）` 分支），而那份
  /// 副本在扩节**成功后**就落盘了。中止时如果只把 `TimetableSettings` 写回去
  /// （含 `activeTimeSchemeId`），副本会带着新的 UUID 留在内存与盘上，并出现在
  /// 用户的作息模板列表 / 模板选择器 / 加课页的方案名里 —— 用户反复取消导入就
  /// 反复累积，且**没有任何自动清理路径**（`_doEnsureTimeSchemesInitialized`
  /// 只新增、从不删除未被引用的方案）。
  ///
  /// 用 id 差集判断「本次新建的」而不是让调用方回传 id：恢复点本来就该把
  /// 「这一趟导入造成的一切作息变化」整体退掉，不该依赖调用方记得传什么。
  final Set<String> schemeIds;

  /// 只删**导入自己造出来的**那一份：名字带「（导入补齐）」后缀的那条副本。
  ///
  /// ⚠️ 这里刻意**不是**「捕获后新增的全部」。教务导入也会**为用户新建**一套
  /// 真正的作息（`_applyImportedSections` 的 `createTimeScheme`，名字是学校名），
  /// 那套是用户要留着用的 —— 删掉它等于把用户刚导入的作息配置抹了。既有回归
  /// `import_time_scheme_restore_point_test.dart` 的第一条就明确写着「教务那套
  /// 模板本身留着没关系（用户可能还要用），但不能是当前生效的」。
  ///
  /// 判据用名字后缀而不是"是不是副本形状"：副本的名字是那条分支里唯一
  /// 100% 由本仓拼出来的标记（`'${currentScheme.name}（导入补齐）'`），
  /// 用户的作息不可能正好叫这个。而它落进用户可见的模板列表也正是这个后缀。
  Iterable<TimeScheme> get _importSupplementSchemes => host.timeSchemes
      .where(
        (scheme) =>
            !schemeIds.contains(scheme.id) &&
            scheme.name.contains(importSupplementNameSuffix),
      );

  /// 把作息切回捕获时那一份。
  ///
  /// 恢复失败**不抛出**：调用点在 `finally` 里，抛出去会把原始错误盖掉，
  /// 而且行程已经结束，用户不该再看到第二个错。
  Future<void> restore() async {
    await _removeSchemesCreatedDuringImport();
    try {
      final rejected = await host.updateTimetableSettings(settings);
      if (rejected != null && kDebugMode) {
        // 正常路径不该走到这里：中止时课程没落地，捕获的那份节次表本来就合法，
        // 撞不上 `section_count_below_usage`。真撞上了留个痕，便于回捞。
        debugPrint('import time scheme restore rejected: $rejected');
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('import time scheme restore failed: $error');
      }
    }
  }

  /// 删掉本次导入期间新建的作息（扩节副本）。
  ///
  /// 顺序上先删副本再恢复设置：删完若 `activeTimeSchemeId` 还指着它，
  /// `_isSchemeInUse` 会判定"仍在使用"而拒绝删除 —— 先切回去再删就没有这个
  /// 依赖。但删除本身也可能抛错（落盘失败），那种情况下**不能**让清理失败
  /// 盖掉恢复设置的语义，所以独立 try。
  ///
  /// 先切再删的一个副作用要认：`activeTimeSchemeId` 指向的副本在删除前会被
  /// 恢复点切回捕获时的 id（恢复点只切设置、不删方案，所以此刻方案还在），
  /// 于是删除时它已无引用，能删掉。
  Future<void> _removeSchemesCreatedDuringImport() async {
    final created = _importSupplementSchemes.toList();
    if (created.isEmpty) {
      return;
    }
    // 先把设置切回捕获时那一份，`activeTimeSchemeId` 才不再指向这些副本。
    try {
      await host.updateTimetableSettings(settings);
    } catch (_) {
      if (kDebugMode) {
        debugPrint('import time scheme restore (pre-clean) failed');
      }
      return;
    }
    for (final scheme in created) {
      try {
        await host.deleteTimeScheme(scheme.id);
      } catch (error) {
        if (kDebugMode) {
          debugPrint('import time scheme cleanup failed for ${scheme.id}: $error');
        }
      }
    }
  }
}
