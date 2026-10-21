import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/screens/more_features_screen.dart';
import 'package:university_timetable/widgets/home_menu_catalog.dart';

/// 「更多功能」汇总页的收录契约（行为断言 + 接线源码检查）。
///
/// 收录标准（用户 2026-10-21 拍板）：**全量功能目录**——目录里除「偏好设置」
/// 分类（设置子页有设置首页这个固定归宿）与「更多功能」自身外的全部可见
/// 条目。不维护手工清单：此前手筛 10 条漏了总览/统计/考试这些「默认排列里
/// 有、被移出后就没处找」的页，还把统计设置误收了进来。
///
/// 接线部分（目录↔路由表 id 对齐）保持源码级检查：两张表是两个文件里的
/// 字符串，id 对不上时 `homePage()` 在点开那一刻才抛 `StateError`（启动不炸、
/// 测试全绿、真机一点就崩）；import 整棵页面树去查会让本测试背上整个 App
/// 的编译面。
void main() {
  final catalogFile = File('lib/widgets/home_menu_catalog.dart');
  final registryFile = File('lib/screens/home_menu_route_registry.dart');
  final pageFile = File('lib/screens/more_features_screen.dart');

  test('三个接线文件都在（否则本测试空转）', () {
    expect(catalogFile.existsSync(), isTrue, reason: catalogFile.path);
    expect(registryFile.existsSync(), isTrue, reason: registryFile.path);
    expect(pageFile.existsSync(), isTrue, reason: pageFile.path);
  });

  test('八宫格目录里有 more 条目，标题走 l10n、打开 morePage', () {
    final source = catalogFile.readAsStringSync();
    expect(
      source.contains("id: 'more'"),
      isTrue,
      reason: '目录里没有 id: more —— 用户在编辑器里看不到「更多功能」',
    );
    expect(
      source.contains("homePage('morePage')"),
      isTrue,
      reason: '条目没有指向 morePage（点开会在 homePage 抛 StateError）',
    );
    expect(
      source.contains('homeMenuMoreTitle'),
      isTrue,
      reason: '标题必须走 l10n（硬编码中文会被 CJK 审计拦下）',
    );
  });

  test('路由表登记了 morePage → MoreFeaturesScreen', () {
    final source = registryFile.readAsStringSync();
    expect(source.contains("id: 'morePage'"), isTrue);
    expect(
      source.contains('MoreFeaturesScreen()'),
      isTrue,
      reason: '描述符的 build 没有造 MoreFeaturesScreen',
    );
    expect(
      source.contains("import 'more_features_screen.dart';"),
      isTrue,
      reason: '路由表缺 import，build 会编译不过',
    );
  });

  test('底栏内嵌表也登记了 more（缺了就是「底栏消失」的回归）', () {
    final source = registryFile.readAsStringSync();
    // 取件码踩过的坑：只登记目录表时，底栏点它会推一个全新页面、坞消失。
    expect(
      RegExp(r"_inlineDockPageDescriptors = \[[\s\S]*?id: 'more'").hasMatch(
        source,
      ),
      isTrue,
      reason: '内嵌表里没有 more：底栏点它会推新页面、底栏消失',
    );
  });

  test('收录是全量功能目录：除偏好设置与自身外全部收录', () {
    final entries = moreFeaturesEntries();
    final ids = entries.map((entry) => entry.id).toSet();
    // 设置子页一个都不许进（用户点过名：统计设置不该出现在这里——
    // 该收的是统计页本身，设置藏在统计页里）。
    expect(
      entries.every((entry) => entry.category != HomeMenuEntryCategory.preferences),
      isTrue,
      reason: '偏好设置分类（统计设置/天气设置/通用等）不许进汇总页',
    );
    expect(ids.contains('more'), isFalse, reason: '汇总页不许自我收录');
    // 功能页必须全在（漏一个就是用户说的「没找全」）：默认排列里的
    // 也要收——被移出首页后这里仍是它们的入口。
    for (final id in const [
      // 功能入口
      'overview',
      'statistics',
      'exams',
      'tasks',
      'scheduleList',
      'monthView',
      'pickupCode',
      'courseConflict',
      'locationTimeMatch',
      'scheduleDateRule',
      'icsExport',
      'timeSchemes',
      'profiles',
      'importCourses',
      'addCourse',
      'addExam',
      'addTask',
      'addScheduleItem',
      'courseRecolor',
      'shareTimetable',
      'quickSwitchTimetable',
      // 数据与同步
      'dataTransfer',
      'cloudSync',
      'lanEdit',
      'coupleTimetable',
      // 关于与支持
      'aboutApp',
      'update',
      'changelog',
      'userGuide',
      'feedback',
      'openSourceLicenses',
      'support',
    ]) {
      expect(ids.contains(id), isTrue, reason: '功能页 $id 没被收录');
    }
  });

  test('收录与目录同步：目录条目数与收录数一致（新页自动出现）', () {
    final expected = kHomeMenuCatalog
        .where(
          (entry) =>
              entry.category != HomeMenuEntryCategory.preferences &&
              entry.id != 'more' &&
              entry.visible(),
        )
        .length;
    expect(moreFeaturesEntries().length, expected);
  });
}
