import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/campus_tool_link_parser.dart';
import 'package:university_timetable/domain/campus_tool_presets.dart';
import 'package:university_timetable/models/campus_tool_entry.dart';
import 'package:university_timetable/widgets/campus_tool_icons.dart';

/// 预置表的数据契约：这是从 QuickJump 抄来的第三方页面入口，**失效是常态**，
/// 所以这里不钉具体链接字符串，只钉「结构上还站得住」——
/// 每条都有可尝试的目标、包名/链接格式合法、图标名在注册表里、id 不重复。
void main() {
  test('预置 id 唯一且非空，且都在 id 集合里', () {
    final ids = <String>[for (final preset in kCampusToolPresets) preset.id];
    expect(ids.toSet().length, ids.length);
    expect(ids.any((id) => id.trim().isEmpty), isFalse);
    expect(kCampusToolPresetIds.length, ids.length);
    expect(kCampusToolPresetIds.containsAll(ids), isTrue);
  });

  test('每条预置都至少有一个可尝试的目标', () {
    for (final preset in kCampusToolPresets) {
      expect(
        preset.hasTarget,
        isTrue,
        reason: '${preset.id} 没有任何链接 / 应用 / 网页兜底',
      );
      // 预置标题走 l10n（模型里 title 为空），改标题不该靠改数据表。
      expect(preset.title, isEmpty, reason: '${preset.id} 的标题应由 l10n 提供');
    }
  });

  test('链接与包名格式合法，且不会在解析器里被判错', () {
    for (final preset in kCampusToolPresets) {
      for (final link in preset.links) {
        expect(
          isValidCampusToolUri(link.uri),
          isTrue,
          reason: '${preset.id} 的链接不合法：${link.uri}',
        );
        if (link.package != null) {
          expect(
            isValidCampusToolPackage(link.package!),
            isTrue,
            reason: '${preset.id} 的限定包名不合法：${link.package}',
          );
        }
      }
      for (final package in preset.appPackages) {
        expect(
          isValidCampusToolPackage(package),
          isTrue,
          reason: '${preset.id} 的兜底包名不合法：$package',
        );
      }
      final web = preset.webUri;
      if (web != null) {
        expect(
          isValidCampusToolWebUri(web),
          isTrue,
          reason: '${preset.id} 的网页兜底不合法：$web',
        );
      }
    }
  });

  test('预置能原样通过编辑框的解析（往返不丢包名限定）', () {
    for (final preset in kCampusToolPresets) {
      final text = <String>[
        for (final link in preset.links) link.editableLine,
      ].join('\n');
      final parsed = parseCampusToolLinks(text);
      expect(parsed.ok, isTrue, reason: '${preset.id} 的链接行解析失败');
      expect(parsed.links.length, preset.links.length);
      for (var index = 0; index < preset.links.length; index++) {
        expect(parsed.links[index].uri, preset.links[index].uri);
        expect(parsed.links[index].package, preset.links[index].package);
      }
    }
  });

  test('图标名都在注册表里，未知名字回落默认图标', () {
    for (final preset in kCampusToolPresets) {
      expect(
        kCampusToolIcons.containsKey(preset.icon),
        isTrue,
        reason: '${preset.id} 用了未注册的图标名：${preset.icon}',
      );
    }
    expect(kCampusToolIcons.containsKey(kCampusToolDefaultIconName), isTrue);
    expect(campusToolIconFor('no_such_icon'), isNotNull);
  });

  test('默认排列与预置表条数一致，且每次都是新实例', () {
    final first = campusToolDefaultEntries();
    expect(first.length, kCampusToolPresets.length);
    // 预置表是 const：直接把条目交出去会让界面改动与常量共享引用，
    // 下一次「补回默认」读到的就是被改过的值。这里钉「交出去的是副本」。
    expect(identical(first.first, kCampusToolPresets.first), isFalse);
    expect(
      identical(first.first, campusToolDefaultEntries().first),
      isFalse,
    );
  });

  test('补回默认入口：只补缺失项，不重置已有配置', () {
    final customized = <CampusToolEntry>[
      campusToolDefaultEntries()
          .firstWhere((entry) => entry.id == 'campusToolsPresetCainiao')
          .copyWith(title: '我的菜鸟', enabled: false),
      for (final preset in kCampusToolPresets)
        if (preset.id != 'campusToolsPresetCainiao' &&
            preset.id != 'campusToolsPresetTaobao')
          preset,
      const CampusToolEntry(id: 'user-owned', title: '我自己的入口'),
    ];
    final restored = campusToolRestoreMissingPresets(customized);
    expect(restored.length, customized.length + 1);
    final cainiao = restored.firstWhere(
      (entry) => entry.id == 'campusToolsPresetCainiao',
    );
    expect(cainiao.title, '我的菜鸟');
    expect(cainiao.enabled, isFalse);
    expect(
      restored.any((entry) => entry.id == 'campusToolsPresetTaobao'),
      isTrue,
      reason: '被删掉的预置项应当补回',
    );
    expect(
      restored.any((entry) => entry.id == 'user-owned'),
      isTrue,
      reason: '用户自建项不能被重置掉',
    );
    // 已经有全部预置项时，补回不该产生任何变化。
    expect(
      campusToolRestoreMissingPresets(campusToolDefaultEntries()).length,
      kCampusToolPresets.length,
    );
  });
}
