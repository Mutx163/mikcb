import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 「更多功能」汇总页的接线契约（**静态源码检查**，模式照抄
/// `pickup_codes_wiring_test.dart`）。
///
/// 为什么不跑 widget 测试：按 TEST-POLICY，`test/widgets` / `test/screens` /
/// `test/ui` 是冻结目录；且两张表是两个文件里的字符串，id 对不上时
/// `homePage()` 在点开那一刻才抛 `StateError`（启动不炸、测试全绿、真机
/// 一点就崩）。
///
/// 覆盖三件事：
/// 1. 目录 ↔ 路由表的双向登记（`more` 内嵌 + `morePage` 推入 + import）；
/// 2. 汇总页精选清单里的每个 id 都真实存在于目录（改名/下线即红）；
/// 3. 天气设置补进候选目录后与设置库子页工厂对齐。
void main() {
  final catalogFile = File('lib/widgets/home_menu_catalog.dart');
  final registryFile = File('lib/screens/home_menu_route_registry.dart');
  final pageFile = File('lib/screens/more_features_screen.dart');
  final settingsRootFile = File('lib/screens/timetable_settings_screen.dart');

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

  test('汇总页精选清单里的每个 id 都真实存在于目录', () {
    final pageSource = pageFile.readAsStringSync();
    final catalogSource = catalogFile.readAsStringSync();
    // 从页面源码抽出 kMoreFeaturesEntryIds 的 id（不 import 页面树，
    // 保持本测试只背两个文件的字符串，不背整棵 App 的编译面）。
    final block = RegExp(
      r'kMoreFeaturesEntryIds = \[([\s\S]*?)\];',
    ).firstMatch(pageSource);
    expect(block, isNotNull, reason: '页面里找不到 kMoreFeaturesEntryIds 清单');
    final ids = RegExp(r"'([A-Za-z]+)'")
        .allMatches(block!.group(1)!)
        .map((match) => match.group(1)!)
        .toList();
    expect(ids, isNotEmpty, reason: '精选清单是空的');
    expect(ids.toSet().length, ids.length, reason: '精选清单里有重复 id');
    for (final id in ids) {
      expect(
        catalogSource.contains("id: '$id'"),
        isTrue,
        reason: '精选清单里的 id "$id" 不在 kHomeMenuCatalog —— 汇总页会静默丢行',
      );
    }
  });

  test('weatherSettings 补进候选目录并与设置库子页工厂对齐', () {
    final catalogSource = catalogFile.readAsStringSync();
    final settingsSource = settingsRootFile.readAsStringSync();
    expect(
      catalogSource.contains("id: 'weatherSettings'"),
      isTrue,
      reason: '候选目录里没有 weatherSettings —— 用户在八宫格编辑器里加不到天气设置',
    );
    expect(
      catalogSource.contains('weatherSettingsEntryTitle'),
      isTrue,
      reason: '标题必须走 l10n（与设置首页入口共用同一个键）',
    );
    expect(
      settingsSource.contains("'weatherSettings' =>"),
      isTrue,
      reason: '设置库 settingsSubpageById 没有 weatherSettings —— 候选点开是空白',
    );
  });
}
