import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 架构守卫棘轮（OPTIMIZATION.md 阶段 0 收尾：度量进 CI）。
///
/// 守卫值只许下降不许上涨；确需放宽时，把基线改成新值并在提交信息说明
/// 理由。下降后欢迎顺手收紧基线。
void main() {
  const providerPath = 'lib/providers/timetable_provider.dart';
  final providerFile = File(providerPath);

  List<File> libDartFiles() {
    return Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.replaceAll('\\', '/').endsWith('.dart'))
        .toList();
  }

  test('timetable_provider.dart 行数棘轮：只减不增', () {
    // 4400→4407: 合并 PR#20——_loadHolidayDataImpl 的 catch 原为静默吞异常，
    // 补 AppLogService.warn 留痕（+7，error/stackTrace 参数透传所需的 warn
    // 签名早已存在，全部为日志行），按测试约定记真实值。
    // 4401→4409: applyCourseRecolors 整对象替换改为按字段 copyWith（+9，
    // 防过期快照回写非颜色字段），拆分归阶段 3 重构，按测试约定同步基线。
    // 4409→4422: 桌面卡片按课表绑定快照（e7f77af4）+13——Provider 侧只新增
    // buildHomeWidgetSnapshotForProfile 转发入口与逐卡签名去重表，快照构建本体
    // 在 live_activity_controller，属正当增长；拆分归阶段 3 重构。
    // 4422→4426: eec42680 周次口径修复 +19（当时未同步基线），同批自 CNB
    // PR#6 内联三个单调用点私有方法（-15）瘦身，净 +4，按测试约定同步基线。
    // 4426→4398: issue#11 竞态修复（R1 迁移写回包 mutation gate+一致性校验/
    // R2 周次同步与 setCurrentWeek 包 gate/N5 考试提醒单飞收敛，+55）+
    // 死代码删除（loadSettings/loadCourses -78）+ 钟点同步逻辑下沉 domain
    // 薄转发（-70）净 -33，顺手收紧基线到当前真实行数。
    // 4407→4414: issue#14 性能体检——_init 作业标记落盘改后台 persist
    // （经 mutation gate 串行），后台任务封装 +9 行，按约定同步基线。
    // 4419→4433: PR#45 error-handling 的 setCurrentWeek mutation gate /
    // 一致性校验 / 考试提醒单飞收敛属正当修复增长但未同步基线
    // （PR#39 的 4419 基于尚未含 #45 的旧 main），合并后实测 4433，
    // 按测试约定同步真实值。
    // 4433→4440: main 82f55c9d（issue#52 审核 S4）假期存储损坏时区分
    // 「暂无」与「损坏」，Provider 侧新增 loadCustomHolidaysOrNull 薄转发
    // （+7，含注释），合并后实测 4440，按测试约定同步真实值。
    // 4440→4455: 桌面卡片「情侣课表」合并视图（22b6eca7 等）Provider 侧
    // 新增 couple-merged 绑定哨兵对接与快照转发（+15），属正当增长，
    // 拆分归阶段 3 重构，按测试约定同步真实值。
    // 4455→4460: 壁纸「最近使用」历史改设备级全局：Provider 侧只留两条一行调用
    // 入口（启动时收拢 + 导入后并集），迁移/并集逻辑与错误日志全部下沉
    // WallpaperHistoryService，+5 全是调用行与注释行，按测试约定同步真实值。
    // 4460→4489: 调试版/性能版「渲染性能设置快照」——Provider 侧只新增一个私有转发
    // _logPerformanceSnapshotIfChanged（含说明注释）与两处一行调用（updateTimetableSettings
    // / updateSettings），快照构建与指纹判断全在 lib/logging/performance_settings_snapshot.dart，
    // Provider 未新增业务逻辑，按测试约定同步真实值。
    // 4489→4499: 「假期课被过滤」类 UI 断言需要一份不触发桌面卡片/超级岛重排的
    // 种数据入口，Provider 侧新增 @visibleForTesting 的 seedHolidayDataForTesting
    // （+10，只赋值 + notifyListeners，无业务逻辑），按测试约定同步真实值。
    // 4499→4532: 应用级偏好（导航 / 材质 / 主题外观 / 通用）改设备级全局：
    // 迁移、覆盖、抽取、导入重推全部下沉 AppGlobalSettingsService，Provider 侧只有
    // 三个「读」处改走 _settingsFromProfile（叠全局那份）、一处落盘口加 syncFrom、
    // 启动与导入各一次调用 —— +33 全是边界接线与注释，无业务逻辑。真源依旧是
    // service，本类未新增任何状态机。
    // 4532→4620：审核修复补上完整备份回滚、启动后台写入收尾、
    // 导入等待和失败路径处理；这些是持久化一致性边界，不是继续堆业务状态。
    // 4620→4640：_trackStartupBackgroundWrite 就地接住「task 自身失败」——
    // 原来链上的 onError 只接上一条的错，最后一条失败会让 _startupBackgroundWrites
    // 停在失败态，随后被导入入口 await 到，抛出与导入无关的启动期异常。
    // 改动只有一层错误处理 + 一段说明，无新增状态。
    // 4640→4647：设置镜像事务接入 _persistActiveProfileState，新增一次
    // hasPendingChanges 分支和事务包装调用；恢复记录本身在 StorageService。
    // 4647→4653：ff0ae83d 把周次推导从手写式（本地 DateTime.difference().inDays
    // ~/ 7，跨夏令时少算一周）换成既有的 WeekCalculator.getWeekIndex。业务行数
    // 净减（3 行推导换成 2 行调用），+6 全是解释「为什么不能用 difference()」的
    // 注释——这类注释正是本基线想留下的可追溯性。按测试约定同步真实值。
    // 4653→4809：本基线在上游就已经被突破（18e95da 实测 4809 > 4653），也就是说
    // main 分支这条棘轮一直是红的 —— 记录在案，避免下一个人以为是审计改坏的。
    // 4809→4875：本轮修复的正当增长，全部是守门与回滚接线，无新增业务状态机：
    // · 11 个写入口收进 _mutationGate（作息 6 + 地点分组 4 + persistHomeViewState），
    //   每个入口 +2~3 行的包装与闭合；
    // · updateTimetableSettings 抽出 _updateTimetableSettingsGated 以便一眼看出包门
    //   形状（+6，含说明注释）；
    // · updateCourseGroup 空集合守卫、主题族 _applySavedThemes 回滚、
    //   HolidayService 注入所有权、_syncCourseWithEffectiveTimeScheme 越界星期拒收。
    // 按测试约定同步真实值；拆分仍归阶段 3。
    // 4875→4912：地点分组的落盘失败回滚。新增 `_commitLocationGroupChange`
    // （25 行：抓 4 份内存快照 + 失败退回 + 尽力把旧分组重新落盘 + rethrow），
    // 三个入口各改成"抓旧列表 → 改内存 → 交给收口函数写"。与已经收口的
    // `_applySavedThemes`（主题族）、`_timetableUpdateTimeScheme`（作息）同形，
    // 不是新业务状态机；作息/导入那两处的同类收口在 part 文件里，不占本数字。
    // 4912→4943：提醒与导入的两处写锁收口。
    // · `setClassReminder`/`removeClassReminder` 原先在门外读 `settings` 整份快照、
    //   再 `await updateSettings(...)` 在门内整表替换 —— 并发设两节课的提醒时
    //   后完成者把前者抹掉且双方都报成功。新增 `_mutateSettings`（读-改-写在同一次
    //   持锁里完成，10 行含注释），两个入口改用（+21）。
    // · `ensureSectionCapacityForImport` 全程在门外改 `_settings`/`_timeSchemes`
    //   并落盘，与同文件其它导入入口的加锁口径相反，改为走
    //   `runMutationExclusive`（+10，含注释）。
    // 都不是新业务状态机，是把已认定的门纪律补到漏掉的写入口。
    // 4943→4972：deleteProfile 的落盘失败回滚（+29，其中 14 行是注释）。
    // 删除激活档案时它会先 removeAt + 切到备用课表并 _applyProfileState，
    // 两次 saveProfiles/setActiveProfileId 都在门外无 try/catch：抛错就是
    // "内存里课表已经没了、盘上还在"，而下一次任意成功写入会把删除坐实。
    // 回滚形状与同文件 switchProfile（:2445-2459）一致，不是新业务状态机。
    // 4972→4869（本仓第一次往下调）：日期规则族补落盘失败回滚时，顺手把
    // 「到点批量套用」的 146 行主体移入 part 文件 `timetable/schedule_date_rule_repository.dart`
    // （原 :1751-1896，本类里最长的写路径之一）。移出不是为绕开本棘轮：它原本就该和
    // 作息族 `_timetableApplyTimeScheme`、地点分组族 `_commitLocationGroupChange` 同处
    // ——三族做的是同一件事（改默认作息 + 重写未锁课程钟点 + 落盘），回滚形状也必须
    // 一起改。本文件里只留一层委托（7 行），四个 CRUD 入口各加一段"规则没落成功就退回原列表"。
    // 4869→4773：课程组（同名多课次）的三个整组写入口移出 part 文件
    // `timetable/course_group_repository.dart`（原 :2593-2613 delete、:2840-2878 update、
    // :2888-2935 add），同时给 delete/update 补上落盘失败回滚 —— 这两处会连带摘掉挂在
    // 这组课上的考试与作业，而用户点的是"删课程"，失败后必须一起退回；add 刻意不回滚
    // （内存里正是用户刚填的内容），判据写在 part 文件开头。本文件净减 96 行。
    // 4773→4716：同一族再往下收。`deleteCourse`（原 :2576-2591）与 `updateCourse`
    // （原 :2517-2574）移出 part 文件 `timetable/course_repository.dart` 并补回滚：
    // 前者连带摘掉该课名下的考试与作业，后者把共享字段广播给同组其它课次 —— 改的
    // 不全是用户正在编辑的那一条，落盘失败时必须一起退回（`addCourse` 仍不回滚，
    // 口径同上）。本文件只留两层委托（19 行）。
    // 4716→4649：写入纪律的最后两处"会波及其它记录"的入口，同批收口（一个提交里两条
    // 修复，判据与注释口径共用）：`_clearActiveProfileCoursesImpl`（原 :3821-3839，
    // 清整份课程 + 全部挂课作业，影响面最大）移入 `timetable/course_repository.dart`，
    // `updateScheduleItem`（原 :2960-2997，改系列根会连带销毁该系列全部单次覆盖行）与
    // `deleteScheduleItem`（原 :2999-3023，整系列摘除）移入新 part 文件
    // `timetable/schedule_item_repository.dart`。`addScheduleItem` 与 occurrence 级的
    // 编辑/删除仍不回滚（改的就是用户这次确认的内容），理由写在两个 part 文件开头。
    // 4649→4631：钟点排序规则收口时顺手做的正当瘦身 —— `_sortScheduleItems`
    // 从类成员改成 `timetable/schedule_item_repository.dart` 里的库级私有函数
    // （同一个 library，调用点不用改写法；日程的存量顺序本来就和那两个写入口同族）。
    // 起因是这条修复本身让父文件从 4649 涨到 4654、把棘轮判红：正确做法不是抬高基线，
    // 而是把新写的规则放回它该在的分片里。
    // 4631→4630：周报钩子收口 —— `_persistActiveProfileState` 的镜像分支原先手工
    // 只补 `notifyUserDataChangedForSync()`，两条分支的「落盘成功后副作用」现在统一
    // 走 `timetable/live_activity_controller.dart` 里的 `_afterProfilePersisted`。
    // 4630→4622：`updateSettings` 补落盘失败回滚时，把节次表归一规则
    // `_normalizeSettingsWithTimeScheme` 与快照/回滚 helper 一起移进新分片
    // `timetable/settings_repository.dart`（棘轮的既定做法：规则放回它该在的分片，
    // 不是抬基线）。
    const baselineLines = 4622;
    final lines = providerFile.readAsLinesSync().length;
    expect(
      lines,
      lessThanOrEqualTo(baselineLines),
      reason:
          '向上帝类继续堆积被禁止（解耦方案阶段 3 将拆分本类）。'
          '若确有正当增长，请同步调高本基线并在提交信息说明。',
    );
  });

  test('timetable_provider 的 lib 扇入棘轮：只减不增', () {
    // 48→51：扇入检测原先只匹配相对路径 import，package:university_timetable/
    // 与 lib 根相对路径可绕过守卫（实际漏网 3 处：main.dart、class_reminder_sheet.dart、
    // home_menu_catalog.dart）。补漏后按真实扇入 51 设基线，后续只许下降。
    // 51→52：新增日程安排列表页 schedule_list_screen.dart（任务清单/考试安排的
    // 同构管理页），与 add_schedule_item_screen 等兄弟页同样需要响应式读取
    // scheduleItems 与 deleteScheduleItem，属正当的同形依赖；分组排序逻辑
    // 已下沉纯 Dart domain（schedule_list_grouping），Provider 零改动，
    // 按测试约定同步真实值。
    // 52→54：课表分享图（截屏后一键分享 / 菜单「分享课表图片」）新增两个文件
    // 直接依赖 Provider——widgets/timetable_export_document.dart（日视图调
    // getCoursesForDay 拿当天课程；周视图把 provider 原样转交屏内同款的
    // TimetableWeekPreview，那是既有的独立依赖）与 services/
    // timetable_share_service.dart（装配该文档并走离屏光栅化后分享）。
    // 两者都是「读当前课表状态出图」的同形依赖，属于该功能的必要读取面，
    // Provider 本身零改动，按测试约定同步真实值。若要收回这两个名额，
    // 需把 TimetableWeekPreview 改成接收数据快照而非 Provider，属阶段 3 解耦范围。
    const baselineFanIn = 54;
    final importers = libDartFiles()
        .where(
          (file) =>
              !file.path.replaceAll('\\', '/').endsWith(providerPath) &&
              RegExp(
                "import\\s+['\"][^'\"]*providers/timetable_provider\\.dart['\"]",
              ).hasMatch(file.readAsStringSync()),
        )
        .length;
    expect(
      importers,
      lessThanOrEqualTo(baselineFanIn),
      reason:
          '新文件不应再直接依赖 TimetableProvider；'
          '确需依赖时同步调高本基线并说明理由。',
    );
  });

  test('_persistActiveProfileState 调用点棘轮：写放大只减不增', () {
    // 48→49：设置保存失败时需要一次补偿性持久化，把两份存储都拉回旧值。
    const baselineCallSites = 49;
    final partFiles = [
      providerFile,
      File('lib/providers/timetable/import_export_service.dart'),
      File('lib/providers/timetable/time_scheme_repository.dart'),
      File('lib/providers/timetable/live_activity_controller.dart'),
    ];
    const marker = '_persistActiveProfileState(';
    var callSites = 0;
    for (final file in partFiles) {
      callSites += marker.allMatches(file.readAsStringSync()).length;
    }
    expect(
      callSites,
      lessThanOrEqualTo(baselineCallSites),
      reason: '全量覆写调用点是阶段 2 要消灭的写放大指标，不应新增。',
    );
  });

  test('lib/domain 保持无 UI 框架依赖（纯领域层）', () {
    final forbidden = RegExp(
      r'''import\s+['"]package:flutter/(widgets|material|cupertino)\.dart['"]''',
    );
    final violations = <String>[];
    for (final file in Directory('lib/domain').listSync().whereType<File>()) {
      if (!file.path.endsWith('.dart')) {
        continue;
      }
      if (forbidden.hasMatch(file.readAsStringSync())) {
        violations.add(file.path.replaceAll('\\', '/'));
      }
    }
    expect(
      violations,
      isEmpty,
      reason:
          '领域层只允许纯 Dart 与 models 依赖（flutter/foundation 例外）；'
          '发现 UI 依赖请上移到 UI 层或改依赖注入。',
    );
  });

  test('两个 fork 补丁依赖不许被摘掉或换回 pub.dev', () {
    // 这两条 override 背的是「不修就复现」的性能修复，摘掉不会让任何行为测试变红：
    //   flutter_miuix（Mutx163/flutter_miuix，分支 glassy-surface）
    //     · 形变动效期间不逐帧模糊内容与来源卡片；
    //     · 非着色器档位降离屏倍率 + 叠色合进同一张画布（见
    //       .agents/notes/implemented/process/2026-09-17-miuix-glass-offscreen-and-blend-patch.md）；
    //     · 底部弹窗（MiuixOverlayBottomSheet / MiuixWindowBottomSheet）的面板材质
    //       注入点 `surfaceBuilder` + 蒙层之前的前置层 `scrimUnderlay` + 蒙层色
    //       `dimColor`，以及 Window 变体「父级重建时不在构建期标脏」的时序修复 ——
    //       课程弹窗的液态玻璃与不采到压暗页面全靠它们（见
    //       .agents/notes/implemented/architecture/2026-09-19-course-popup-miuix-bottom-sheet.md）；
    //     · 弹层输入与视觉拆开：内容**显影之前不吃点击**、锚点**收起期第一帧就收回
    //       输入**（用户快速连点「更多」会误跳页面、收起后立刻再点会丢点击）。这条
    //       有行为测试兜着（test/widgets/home_menu_navigation_close_test.dart 两条 +
    //       fork 侧 os4_glass_popup_test 两条），见
    //       .agents/notes/implemented/bug-fix/2026-09-23-popup-input-visual-split.md；
    //     · 底部弹窗**收起一开始就把输入还给底层**（全屏蒙层原要等退场弹簧结算完才
    //       移除，那约 500ms 里「关掉弹窗马上点下一节课」的第二下会被吃掉）。
    //       同样有行为测试兜着（test/ui/hyperos/miuix_bottom_sheet_test.dart 两条 +
    //       fork 侧 bottom_sheet_dismiss_test 一条，见同一篇笔记的续节）。
    //   inspire_blur（Mutx163/inspire_blur，分支 mikcb/distribution-pixels-cache）
    //     · 分布图像素记忆化——否则每个新挂载的子页顶栏同步重算 674k 像素（36~49ms）。
    // 所以这里只钉「还在不在、是不是那个 fork」，不钉具体 commit：补丁迭代只该改 ref，
    // 不该顺手改这个测试。
    const expected = {
      'flutter_miuix': 'https://github.com/Mutx163/flutter_miuix.git',
      'inspire_blur': 'https://github.com/Mutx163/inspire_blur.git',
    };
    // 按行取块，不按字符串切片：本仓检出在 Windows 下是 CRLF。
    final lines = File('pubspec.lock').readAsLinesSync();
    final entryStart = RegExp(r'^  \S');
    final blocks = <String, String>{};
    for (final name in expected.keys) {
      final start = lines.indexWhere((line) => line == '  $name:');
      expect(
        start,
        isNonNegative,
        reason: 'pubspec.lock 里没有 $name —— 跑过 pub get 吗？',
      );
      var end = start + 1;
      while (end < lines.length && !entryStart.hasMatch(lines[end])) {
        end++;
      }
      blocks[name] = lines.sublist(start, end).join('\n');
    }
    for (final entry in expected.entries) {
      final block = blocks[entry.key]!;
      expect(
        block,
        contains('source: git'),
        reason: '${entry.key} 变成了非 git 依赖（回到 pub.dev？）：$block',
      );
      expect(
        block,
        contains('url: "${entry.value}"'),
        reason: '${entry.key} 的来源仓库不是本项目 fork：$block',
      );
      // 引号不算契约的一部分：pub 写 lock 时，**这一轮被重新解析过的那条**会用
      // 默认风格（裸值），没动过的沿用旧风格（带引号）。2026-09-19 给 flutter_miuix
      // 换 ref 之后就出现过「同一个文件里一条带引号、一条裸值」。这里只钉
      // 「resolved-ref 是 40 位 commit」这件事本身。
      expect(
        RegExp(r'resolved-ref: "?[0-9a-f]{40}"?').hasMatch(block),
        isTrue,
        reason: '${entry.key} 的 ref 不是钉死的 40 位 commit：$block',
      );
    }
  });
}
