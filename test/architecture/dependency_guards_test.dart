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
    const baselineLines = 4653;
    final lines = providerFile.readAsLinesSync().length;
    expect(
      lines,
      lessThanOrEqualTo(baselineLines),
      reason:
          '向上帝类继续堆积被禁止（解耦方案阶段 3 将拆分本类）。'
          '若确有正当增长，请同步调高本基线并在提交信息说明。',
    );
  });

  test('timetable_provider 的读取调用点棘轮：只减不增', () {
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
    //
    // 2026-10-06 换计数单位：原指标数的是「有多少个文件 import 了 Provider」。
    // 该指标对文件布局敏感——把一个文件拆成 5 个、5 个都需要 Provider，计数就
    // 从 1 涨到 5，而依赖边一条没多。于是拆分这种**改善**动作会让门禁转红，
    // 逼着下一个动它的人二选一：不拆（退回巨型文件），或再抬一次基线。
    // 等于用制度给「不拆分」发奖金。2026-10-06 那次拆分就被迫把 54 抬到 56，
    // 而拆分前真实扇入只有 52 —— 名额从「剩 2 格」变成「一格不剩」。
    //
    // 改为数 `read/watch/select/of<TimetableProvider>(` 的**调用点总数**：
    // 它只统计实际发生的读取，与文件怎么切分完全无关。实测拆分前后都是 224
    // （纯搬移不改调用点数），把三处逐字重复的
    // `WarehouseFetchOptions.fromSettings(context.read<TimetableProvider>().settings)`
    // 合并进 import_shared 的 currentWarehouseFetchOptions() 后降到 222 ——
    // 说明这个指标既不会被拆分误伤，也能如实捕捉真实的耦合下降。
    //
    // 旧的 48→51→52→54 那串数字记的是文件数，与本指标不同量纲，不可直接比较。
    // 拆分剩下的 5 个 import/ 文件（ics / 表格 / AI 图片 / 仓库网页登录 /
    // import_shared 的 ensureImportSectionCapacity）都要经 Provider 写课表，
    // 是导入链路的必要写入面。要收回它们，需把导入写入改成接收「课表写入接口」
    // 而非 Provider，与上面 TimetableWeekPreview 那条同属阶段 3 解耦范围。
    //
    // 2026-10-06 补正则漏网：上面那个正则要求 `<TimetableProvider>` 紧跟 `(`，
    // 于是 `context.select<TimetableProvider, TimetableSettings>((p) => p.settings)`
    // 这类**带第二个类型实参**的写法一个都数不到——而它和 read<TimetableProvider>()
    // 是完全同类的读取。实测漏了 3 处，全在 about_screen.dart（209 / 649 / 1567）。
    // 这正是本仓审计笔记已记过一次的坑（`invokeMethod(` 漏掉 `invokeMethod<bool>(`，
    // 见 notes/proposed/2026-09-29-full-architecture-audit-verified.md §4d）：
    // 正则写窄 → 统计偏低 → 基线偏低 → 门禁形同虚设。故把类型实参写成可选。
    //
    // 222→225 不是耦合增长，是把本就存在、此前没被数到的 3 处读取补进计数。
    //
    // 本指标**已知不覆盖**的写法（有意不纳入，别拿它们当"没依赖"）：
    //   - `Consumer<TimetableProvider>`（15 处，整棵子树订阅，是另一种机制）
    //   - `required TimetableProvider provider` 这类把 Provider 当参数传递的位置
    //     （如 import_shared 的 ensureImportSectionCapacity）
    // 要覆盖它们需另立指标，别直接扩这个正则——会把不同性质的依赖混进一个数字。
    //
    // 2026-10-06 再补一处同类漏网：类型实参写死成 `<TimetableProvider>`，于是**可空**
    // 读取 `context.read<TimetableProvider?>()` 一处都数不到——而这恰恰是弹窗 /
    // 半屏 sheet 里最该用的写法（上层可能没注册这个 Provider，只能读可空再判空）。
    // 实测漏 3 处，全在 user_guide_screen.dart（304 / 650 / 786）。
    // 与上一条同源：正则写窄 → 统计偏低 → 基线偏低 → 门禁形同虚设，故一并放宽。
    // 225→228 不是耦合增长，是把本就存在、此前没被数到的 3 处读取补进计数。
    //
    // 「扇入」这个名字如今名不副实：本指标数的是**读取次数**，不是依赖边。文件怎么拆
    // 都不再影响它（这正是换单位的全部理由），代价是覆盖不到纯类型依赖——当前有 14
    // 个文件 import 了 Provider 却没有一处匹配读取（同步 / WebDAV / 统一传输 /
    // 课表分享 / 统计页等，它们把 Provider 当参数类型往下传或只取其类型）。新开一个
    // 文件若只干这两件事，本指标不会响；要覆盖需另立「import 但零读取的文件数」
    // 棘轮（当前真实值 14），同样别直接扩本正则。
    //
    // 余量为 0：基线就是当前实测值，正当新增读取时照例抬基线并说明理由。
    const baselineProviderCallSites = 228;
    final callSitePattern = RegExp(
      r'\b(?:read|watch|select|of)<TimetableProvider\??\s*(?:,[^>]*)?>\s*\(',
    );
    var callSites = 0;
    final touchedFiles = <String>[];
    for (final file in libDartFiles()) {
      if (file.path.replaceAll('\\', '/').endsWith(providerPath)) continue;
      final hits = callSitePattern.allMatches(file.readAsStringSync()).length;
      if (hits > 0) {
        callSites += hits;
        touchedFiles.add(file.path);
      }
    }
    expect(
      callSites,
      lessThanOrEqualTo(baselineProviderCallSites),
      reason:
          '新代码不应再直接读取 TimetableProvider（共 ${touchedFiles.length} 个文件、'
          '$callSites 处调用）；确需依赖时同步调高本基线并说明理由。',
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
