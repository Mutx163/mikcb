import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/screens/more_features_screen.dart';
import 'package:university_timetable/widgets/home_menu_catalog.dart';

/// 「更多功能」页的收录契约（白名单，2026-10-21 定位纠正后）。
///
/// ## 这个测试守的是什么
///
/// 收录标准是**白名单**：只收「别处没有固定入口」的功能页，见
/// `kMoreFeaturesEntryIds`。判据是**目的地有没有其他固定入口**，不是
/// 「它在不在八宫格候选池里」——后者是首页快捷位的判据，两者混用正是
/// 本页一度变成 32 格大杂烩的根因。
///
/// 所以这里断言三件事：
/// 1. **必收**（唯一入口 + 链式断裂那 9 条）一个都不许少——少一条就是
///    用户点不到那个功能，本页存在的理由就是它们；
/// 2. **不许收**（创建动作、瞬时动作、设置页/关于页已有一级入口的）一个都
///    不许混进来——混一条，这一页就往「大杂烩」滑一步；
/// 3. 白名单里的 id 都在目录里真实存在（拼错 id 时目录查不到，条目会静默
///    消失，页面看上去只是「少了一格」）。
///
/// 接线部分（目录↔路由表 id 对齐）仍走源码级检查：两张表是两个文件里的
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

  group('必收：别处找不到入口的功能页', () {
    test('9 条唯一入口/链式断裂页全部在收录结果里', () {
      final ids = moreFeaturesEntries().map((entry) => entry.id).toSet();
      // 每一条的「为什么它进得来」写在 kMoreFeaturesEntryIds 的注释里；
      // 这里只钉「在不在」。掉一条 = 用户点不到那个功能。
      for (final id in const [
        // 全应用唯一入口
        'pickupCode',
        'monthView',
        'statistics',
        'exams',
        'scheduleList',
        'importCourses',
        // 入口存在但实际找不到
        'overview',
        'tasks',
        'courseConflict',
      ]) {
        expect(ids.contains(id), isTrue, reason: '唯一入口 $id 没被收录');
      }
    });

    test('收录数量就是白名单里的有效条数（不多不少）', () {
      final byId = {
        for (final entry in kHomeMenuCatalog) entry.id: entry,
      };
      final expected = kMoreFeaturesEntryIds
          .where((id) => byId[id]?.visible() ?? false)
          .length;
      expect(moreFeaturesEntries().length, expected);
    });
  });

  group('不许收：混进来就往大杂烩滑一步', () {
    test('创建动作不进（各自有列表页的「+」）', () {
      final ids = moreFeaturesEntries().map((entry) => entry.id).toSet();
      for (final id in const [
        'addCourse',
        'addExam',
        'addTask',
        'addScheduleItem',
      ]) {
        expect(
          ids.contains(id),
          isFalse,
          reason: '$id 是创建动作，它有上下文入口；进目录会让用户分不清'
              '「点下去是去一个地方还是发生一件事」',
        );
      }
    });

    test('瞬时弹层动作不进（不是目的地）', () {
      final ids = moreFeaturesEntries().map((entry) => entry.id).toSet();
      for (final id in const [
        'courseRecolor',
        'shareTimetable',
        'quickSwitchTimetable',
      ]) {
        expect(
          ids.contains(id),
          isFalse,
          reason: '$id 是弹层动作，不是页面目的地',
        );
      }
    });

    test('设置首页已有一级行的不进（那份还带回显状态）', () {
      final ids = moreFeaturesEntries().map((entry) => entry.id).toSet();
      for (final id in const [
        'profiles',
        'timeSchemes',
        'dataTransfer',
        'cloudSync',
        'lanEdit',
        'coupleTimetable',
        'userGuide',
      ]) {
        expect(
          ids.contains(id),
          isFalse,
          reason: '$id 在设置首页是一级行且带回显状态；本页的同名瓷贴'
              '没有状态，严格劣于那一份',
        );
      }
    });

    test('关于页二级重复的不进', () {
      final ids = moreFeaturesEntries().map((entry) => entry.id).toSet();
      for (final id in const [
        'update',
        'support',
        'aboutApp',
        'changelog',
        'feedback',
        'openSourceLicenses',
      ]) {
        expect(
          ids.contains(id),
          isFalse,
          reason: '$id 在关于页已有入口，平铺到这里是第三份',
        );
      }
    });

    test('偏好设置分类整组不进（设置子页的归宿是设置首页）', () {
      expect(
        moreFeaturesEntries().every(
          (entry) => entry.category != HomeMenuEntryCategory.preferences,
        ),
        isTrue,
        reason: '偏好设置分类不许进本页',
      );
    });

    test('本页不自我收录', () {
      final ids = moreFeaturesEntries().map((entry) => entry.id).toSet();
      expect(ids.contains('more'), isFalse, reason: '本页不许自我收录');
    });

    test('藏在配置页里的那 3 条也不进（该由宿主页负责提示）', () {
      final ids = moreFeaturesEntries().map((entry) => entry.id).toSet();
      for (final id in const [
        'locationTimeMatch',
        'scheduleDateRule',
        'icsExport',
      ]) {
        expect(
          ids.contains(id),
          isFalse,
          reason: '$id 已有固定归宿（时间模板页 / 数据传输页），'
              '它们该在宿主页加提示，不是在目录页平铺',
        );
      }
    });
  });

  group('白名单本身的自洽性', () {
    test('白名单里每个 id 都在目录里真实存在（拼错会让条目静默消失）', () {
      final catalogIds = kHomeMenuCatalog.map((entry) => entry.id).toSet();
      final missing = kMoreFeaturesEntryIds
          .where((id) => !catalogIds.contains(id))
          .toList();
      expect(
        missing,
        isEmpty,
        reason: '这些 id 在 kHomeMenuCatalog 里查不到（拼错或条目被删），'
            '页面上会静默少一格：$missing',
      );
    });

    test('白名单没有重复 id（重复会让同一格出现两次）', () {
      expect(
        kMoreFeaturesEntryIds.toSet().length,
        kMoreFeaturesEntryIds.length,
        reason: '白名单里有重复 id',
      );
    });
  });
}
