import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/l10n/app_localizations_zh.dart';
import 'package:university_timetable/screens/more_features_screen.dart';
import 'package:university_timetable/widgets/home_menu_catalog.dart';

/// 「全部功能」页的收录契约（第三版，2026-10-21）。
///
/// ## 三版判据的演变（这个测试跟着改了两次，值当记下来）
///
/// 1. **全量推导**：断言「除偏好设置外全部收录」。产出 32 格，用户说「大杂烩」。
/// 2. **孤儿页白名单**：断言「只收别处没有入口的 9 条」。用户说「外观编辑
///    都没有显示在这里」——判据是**技术可达**，而用户感受是**体感可达**。
/// 3. **现版完整索引**：断言三条判据（整页 / 去一个地方 / 过可见性门控）。
///
/// 所以本测试守的不是「某个数量」，而是**三条判据本身**，以及两次踩过的
/// 具体坑（用户点名的页面必须真的在列表里）。
void main() {
  final catalogFile = File('lib/widgets/home_menu_catalog.dart');
  final registryFile = File('lib/screens/home_menu_route_registry.dart');
  final pageFile = File('lib/screens/more_features_screen.dart');
  final l10n = AppLocalizationsZh();

  // 分组只依赖状态值，不需要真的 TimetableProvider（它的构造要读
  // shared_preferences，测试环境里跑不起来）。这里给两个「有值」的状态，
  // 顺带覆盖「副文本拿得到当前值」那条路径。
  List<MoreFeatureGroup> groups() => buildMoreFeatureGroups(
    l10n,
    activeProfileName: '本学期',
    activeTimeSchemeName: '夏季作息',
  );
  Set<String> ids() => {
    for (final group in groups())
      for (final item in group.items) item.entry.id,
  };

  test('三个接线文件都在（否则本测试空转）', () {
    expect(catalogFile.existsSync(), isTrue, reason: catalogFile.path);
    expect(registryFile.existsSync(), isTrue, reason: registryFile.path);
    expect(pageFile.existsSync(), isTrue, reason: pageFile.path);
  });

  group('接线', () {
    test('八宫格目录里有 more 条目，标题走 l10n、打开 morePage', () {
      final source = catalogFile.readAsStringSync();
      expect(source.contains("id: 'more'"), isTrue);
      expect(source.contains("homePage('morePage')"), isTrue);
      expect(source.contains('homeMenuMoreTitle'), isTrue);
    });

    test('路由表登记了 morePage → MoreFeaturesScreen', () {
      final source = registryFile.readAsStringSync();
      expect(source.contains("id: 'morePage'"), isTrue);
      expect(source.contains('MoreFeaturesScreen()'), isTrue);
      expect(source.contains("import 'more_features_screen.dart';"), isTrue);
    });

    test('底栏内嵌表也登记了 more（缺了就是「底栏消失」的回归）', () {
      final source = registryFile.readAsStringSync();
      expect(
        RegExp(r"_inlineDockPageDescriptors = \[[\s\S]*?id: 'more'").hasMatch(
          source,
        ),
        isTrue,
        reason: '内嵌表里没有 more：底栏点它会推新页面、底栏消失',
      );
    });
  });

  group('用户点名过的页面必须真的在列表里', () {
    test('外观编辑在（第二版漏掉它，用户当场点名）', () {
      expect(
        ids().contains('appearanceEditor'),
        isTrue,
        reason: '外观编辑是用户点名的页面。它只有「设置 → 外观与配色 → 往下'
            '找一行」这一条三层跳转入口，体感等于没有',
      );
    });

    test('首页与导航在（它自己此前不在任何目录里）', () {
      expect(
        ids().contains('homeNavigation'),
        isTrue,
        reason: '首页与导航管的就是「首页放哪些入口」，它自己没有入口属于'
            '「管入口的页面没入口」的死结',
      );
    });

    test('两个盲区都已在候选目录里登记（否则列表会静默跳过）', () {
      final catalogIds = kHomeMenuCatalog.map((entry) => entry.id).toSet();
      for (final id in const ['appearanceEditor', 'homeNavigation']) {
        expect(
          catalogIds.contains(id),
          isTrue,
          reason: '$id 不在 kHomeMenuCatalog 里，buildMoreFeatureGroups '
              '会静默跳过它——页面上什么都不会少，只是那个功能消失了',
        );
      }
    });

    test('homeNavigation 有自己的 open，不依赖设置子页表', () {
      // 走普通目录条目而不是 _settingsSubpageEntry：后者要求 id 在
      // settingsSubpageById 里，而设置域有「行数只减不增」的棘轮守卫，
      // 为一个入口加 5 行会顶爆它（不许抬基线换绿）。
      final source = catalogFile.readAsStringSync();
      final block = RegExp(
        r"id: 'homeNavigation',[\s\S]{0,400}?\)\,",
      ).firstMatch(source);
      expect(block, isNotNull, reason: '目录里找不到 homeNavigation 条目');
      expect(
        block!.group(0)!.contains('HomeNavigationSettingsScreen()'),
        isTrue,
        reason: 'homeNavigation 的 open 没有真的推页面——点了会什么都不发生',
      );
    });
  });

  group('判据一：是整页，不是开关/选择器', () {
    test('主题色、字号这类「改参数」不在列表里', () {
      // 这些不是独立页面，是设置页里的行控件。它们出现在目录里意味着
      // 有人把「一个参数」当成「一个目的地」。
      for (final item in groups().expand((group) => group.items)) {
        expect(
          item.entry.id,
          isNot(anyOf('themeSeed', 'fontSize', 'themeMode')),
          reason: '${item.entry.id} 是参数不是页面',
        );
      }
    });
  });

  group('判据二：是「去一个地方」，不是「发生一件事」', () {
    test('创建动作不进（各自有列表页的「+」）', () {
      final present = ids();
      for (final id in const [
        'addCourse',
        'addExam',
        'addTask',
        'addScheduleItem',
      ]) {
        expect(
          present.contains(id),
          isFalse,
          reason: '$id 是创建动作，混进导航目录会让用户无法预测点下去的后果',
        );
      }
    });

    test('瞬时弹层动作不进（不是目的地）', () {
      final present = ids();
      for (final id in const [
        'courseRecolor',
        'shareTimetable',
        'quickSwitchTimetable',
      ]) {
        expect(
          present.contains(id),
          isFalse,
          reason: '$id 是弹层动作，不是页面目的地',
        );
      }
    });

    test('本页不自我收录', () {
      expect(ids().contains('more'), isFalse);
    });
  });

  group('判据三：过可见性门控', () {
    test('只收 visible() 为真的条目', () {
      for (final item in groups().expand((group) => group.items)) {
        expect(
          item.entry.visible(),
          isTrue,
          reason: '${item.entry.id} 的 visible() 为 false，不该出现在正式版',
        );
      }
    });

    test('白名单里的 id 全部能在目录里解析（拼错会让条目静默消失）', () {
      final catalogIds = kHomeMenuCatalog.map((entry) => entry.id).toSet();
      // 从源码里抠出所有 item('xxx') 的 id，逐个查目录。
      final source = pageFile.readAsStringSync();
      final referenced = RegExp(r"item\(\s*'([A-Za-z]+)'")
          .allMatches(source)
          .map((m) => m.group(1)!)
          .toSet();
      expect(referenced, isNotEmpty);
      final missing = referenced.difference(catalogIds);
      expect(
        missing,
        isEmpty,
        reason: '这些 id 在 kHomeMenuCatalog 里查不到（拼错或条目被删），'
            'buildMoreFeatureGroups 会静默跳过，页面上只是少一行：$missing',
      );
    });
  });

  group('搜索组件必须是官方 Miuix 的', () {
    test('用 MiuixSearchBar + MiuixInputField，不用仓库自写的 HyperosSearchBar', () {
      // 用户 2026-10-21 追问「这个搜索框的放置位置，是 miuix 官方的用法吗」——
      // 当时用的是本仓自写的 HyperosSearchBar（原生 TextField 包一层），
      // 名字像 HyperOS 但不是上游组件。改成官方那对之后钉在这里，防止回退。
      final source = pageFile.readAsStringSync();
      expect(
        source.contains('MiuixSearchBar('),
        isTrue,
        reason: '本页应当用官方 MiuixSearchBar 容器',
      );
      expect(
        source.contains('MiuixInputField('),
        isTrue,
        reason: '本页应当用官方 MiuixInputField 输入框',
      );
      expect(
        source.contains('HyperosSearchBar('),
        isFalse,
        reason: 'HyperosSearchBar 是本仓自写的简化输入框，不是 Miuix 官方组件；'
            '它没有可展开胶囊形态、不处理返回键、也不是 StadiumBorder',
      );
      expect(
        source.contains("import 'package:flutter_miuix/miuix.dart';"),
        isTrue,
        reason: '缺 flutter_miuix import 时上面两个构造根本编译不过',
      );
    });

    test('搜索走全屏浮层，不推新路由', () {
      // 2026-10-21 用户连问三次，最后一版口径才说清：
      //   「这玩意不应该是搜索框往上到页面上面，然后搜索框以外的内容清空，
      //     然后下面显示搜索结果吗，miuix 没有这么写吗」
      // 官方组件（MiuixSearchBar）只管胶囊+取消+content 槽，不管「搜索框上移、
      // 整页清空」；官方**示例 App 的移动端**给的答案就是 OverlayEntry 全屏
      // 浮层。三种做法的取舍见 more_features_search_overlay.dart 的类注释。
      //
      // 钉住两条：① 不许再推独立搜索页（那是死锁与丢位置感的源头）；
      // ② 实现必须走 OverlayEntry，而不是又退回页内展开。
      final source = pageFile.readAsStringSync();
      final overlayFile = File('lib/screens/more_features_search_overlay.dart');
      expect(overlayFile.existsSync(), isTrue, reason: overlayFile.path);
      final overlaySource = overlayFile.readAsStringSync();

      expect(
        source.contains('_MoreFeatureSearchPage'),
        isFalse,
        reason: '又出现独立搜索页了：跳页会让用户丢掉「还在这页」的空间感，'
            '且曾因两级返回口径不一致把返回键锁死（ac0f7ffd）',
      );
      expect(
        source.contains('OverlayEntry('),
        isTrue,
        reason: '搜索层没走 OverlayEntry：官方示例的移动端形态就是根覆盖层上的'
            '全屏浮层，它是「整页清空」这个诉求唯一的实现方式',
      );
      // 返回键的拦截**必须挂在宿主页**，不能挂在浮层里。
      //
      // 这条守卫是 2026-10-21 实测出来的：`PopScope` 靠 `ModalRoute.of(context)`
      // 找到所属路由去登记拦截器；浮层是 Overlay entry，Overlay 在所有路由之上，
      // 它子树里没有 `ModalRoute` 祖先 —— 登记落空，真机表现是「按返回，底下
      // 页面退了、浮层还留在屏幕上」。所以浮层里**不许**出现 PopScope，
      // 宿主页必须有 `canPop: _searchOverlay == null`。
      expect(
        overlaySource.contains('PopScope('),
        isFalse,
        reason: '浮层是 Overlay entry，里面没有 ModalRoute 祖先，PopScope 的登记'
            '会落空——返回键会直接退掉宿主页，浮层留在屏幕上。拦截要挂在宿主页',
      );
      expect(
        RegExp(r'canPop: _searchOverlay == null').hasMatch(source),
        isTrue,
        reason: '宿主页没有 PopScope(canPop: _searchOverlay == null)：搜索开着时'
            '按返回会直接退页，浮层留在屏幕上',
      );
      expect(
        source.contains('_dismissSearchOverlay'),
        isTrue,
        reason: '宿主页没把「这次返回」转成「收浮层」',
      );
      expect(
        overlaySource.contains('outsideEndAction'),
        isFalse,
        reason: '浮层自己画输入框+取消，不走 MiuixSearchBar 的 outsideEndAction 槽；'
            '出现它说明又把「页内展开」那一版搬回来了',
      );
    });

    test('折叠态搜索胶囊不持有焦点（官方移动端形态）', () {
      // 官方 SearchBar.kt 移植说明：折叠态不该抢焦点/弹键盘，点开才进搜索态。
      // 样板间（miuix_showcase_screen.dart）用 IgnorePointer + 透明手势层实现。
      final source = pageFile.readAsStringSync();
      final block = RegExp(
        r'Widget _buildSearchBar[\s\S]{0,1800}',
      ).firstMatch(source);
      expect(block, isNotNull);
      expect(
        block!.group(0)!.contains('IgnorePointer'),
        isTrue,
        reason: '折叠态搜索胶囊必须屏蔽指针，否则点它会抢焦点弹键盘，'
            '而不是进搜索态',
      );
    });

    test('浮层里的输入框也是官方 MiuixInputField（不回归自写输入框）', () {
      // 浮层自己拼「输入框 + 取消」这一行（官方示例同构），但**输入框本身**
      // 仍必须是官方 MiuixInputField：它有胶囊底、清除按钮、占位标签只在
      // 「空且折叠」时显示这些细节。自写 TextField 会把这些都丢掉。
      final overlaySource = File(
        'lib/screens/more_features_search_overlay.dart',
      ).readAsStringSync();
      expect(
        overlaySource.contains('MiuixInputField('),
        isTrue,
        reason: '浮层应当用官方 MiuixInputField 输入框',
      );
      expect(
        overlaySource.contains('HyperosSearchBar('),
        isFalse,
        reason: 'HyperosSearchBar 是本仓自写的简化输入框，不是 Miuix 官方组件',
      );
      expect(
        overlaySource.contains('TextField('),
        isFalse,
        reason: '浮层里裸用 TextField 会丢掉 Miuix 胶囊底与清除按钮',
      );
    });
  });

  group('搜索', () {
    test('空词返回全部分区', () {
      expect(filterMoreFeatureGroups(groups(), '', l10n).length, groups().length);
      expect(
        filterMoreFeatureGroups(groups(), '   ', l10n).length,
        groups().length,
        reason: '只有空格也该当成空词',
      );
    });

    test('搜标题能命中', () {
      final result = filterMoreFeatureGroups(groups(), '月视图', l10n);
      final hitIds = result.expand((g) => g.items).map((i) => i.entry.id);
      expect(hitIds, contains('monthView'));
    });

    test('搜同义词也能命中（界面标题里没有这些词）', () {
      // AOSP 通用搜索的要求：索引要含「用户会搜、但界面上看不到」的词。
      // 中文用户搜「换肤」「皮肤」找外观编辑——标题「外观编辑」一个都不含。
      for (final word in const ['换肤', '皮肤']) {
        final result = filterMoreFeatureGroups(groups(), word, l10n);
        final hitIds = result.expand((g) => g.items).map((i) => i.entry.id);
        expect(
          hitIds,
          contains('appearanceEditor'),
          reason: '搜「$word」应当能找到外观编辑',
        );
      }
    });

    test('搜分区名能露出整个分区', () {
      final result = filterMoreFeatureGroups(groups(), l10n.settingsAboutSectionTitle, l10n);
      expect(result.length, 1, reason: '分区名命中时应当只剩那一个分区');
      expect(result.single.title, l10n.settingsAboutSectionTitle);
      expect(
        result.single.items.length,
        groups()
            .firstWhere((g) => g.title == l10n.settingsAboutSectionTitle)
            .items
            .length,
        reason: '分区名命中要把整区条目都留下，不是只留标题命中的那条',
      );
    });

    test('搜不到时返回空（由页面渲染空态）', () {
      final result = filterMoreFeatureGroups(groups(), 'zzz不存在的词', l10n);
      expect(result, isEmpty);
    });
  });

  group('分组', () {
    test('没有空分区（空分区会渲染成一个只有标题的孤块）', () {
      for (final group in groups()) {
        expect(group.items, isNotEmpty, reason: '分区「${group.title}」是空的');
      }
    });

    test('每个条目只出现一次（同一功能挂两个分区会被用户当成两个东西）', () {
      final all = [
        for (final group in groups())
          for (final item in group.items) item.entry.id,
      ];
      expect(
        all.length,
        all.toSet().length,
        reason: '有条目出现在多个分区里',
      );
    });

    test('分组顺序是任务顺序：课表在最前，关于在最后', () {
      final titles = groups().map((g) => g.title).toList();
      expect(titles.first, l10n.settingsTimetableSectionTitle);
      expect(titles.last, l10n.settingsAboutSectionTitle);
    });
  });
}
