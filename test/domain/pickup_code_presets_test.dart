import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/pickup_code_presets.dart';
import 'package:university_timetable/widgets/pickup_code_icons.dart';

/// 固定入口表的数据契约。
///
/// 这是从 QuickJump 抄来的第三方页面入口，**失效是常态**，所以这里不钉具体
/// 链接字符串，只钉「结构上还站得住」——每条都有可尝试的目标、包名/链接格式
/// 合法、图标名在注册表里、id 不重复、分组不出意外。
void main() {
  test('id 唯一且非空', () {
    final ids = <String>[for (final preset in kPickupCodePresets) preset.id];
    expect(ids.toSet().length, ids.length);
    expect(ids.any((id) => id.trim().isEmpty), isFalse);
  });

  test('每条都至少有一个可尝试的目标', () {
    for (final preset in kPickupCodePresets) {
      final hasTarget = preset.links.isNotEmpty ||
          preset.appPackages.isNotEmpty ||
          (preset.webUri?.trim().isNotEmpty ?? false);
      expect(
        hasTarget,
        isTrue,
        reason: '${preset.id} 没有任何链接 / 应用 / 网页兜底',
      );
    }
  });

  test('链接是 scheme:// 形状，没有危险 scheme', () {
    const blocked = <String>{
      'file',
      'content',
      'javascript',
      'data',
      'intent',
    };
    for (final preset in kPickupCodePresets) {
      for (final link in preset.links) {
        final uri = link.uri;
        final separator = uri.indexOf('://');
        expect(separator, greaterThan(0), reason: '${preset.id}: $uri 不是 scheme://');
        final scheme = uri.substring(0, separator).toLowerCase();
        expect(
          blocked.contains(scheme),
          isFalse,
          reason: '${preset.id} 用了危险 scheme: $scheme',
        );
      }
    }
  });

  test('包名是 a.b.c 形状', () {
    final pattern = RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z0-9_]+)+$');
    for (final preset in kPickupCodePresets) {
      for (final package in preset.appPackages) {
        expect(
          pattern.hasMatch(package),
          isTrue,
          reason: '${preset.id} 的兜底包名不合法：$package',
        );
      }
      for (final link in preset.links) {
        final package = link.package;
        if (package == null) {
          continue;
        }
        expect(
          pattern.hasMatch(package),
          isTrue,
          reason: '${preset.id} 的限定包名不合法：$package',
        );
      }
    }
  });

  test('网页兜底只接受 http(s)', () {
    for (final preset in kPickupCodePresets) {
      final web = preset.webUri;
      if (web == null) {
        continue;
      }
      final lower = web.toLowerCase();
      expect(
        lower.startsWith('http://') || lower.startsWith('https://'),
        isTrue,
        reason: '${preset.id} 的网页兜底不是网址：$web',
      );
    }
  });

  test('图标名都在注册表里，且每个都在用', () {
    for (final preset in kPickupCodePresets) {
      expect(
        kPickupCodeIcons.containsKey(preset.icon),
        isTrue,
        reason: '${preset.id} 用了未注册的图标名：${preset.icon}',
      );
    }
    final used = <String>{for (final preset in kPickupCodePresets) preset.icon};
    final unused = <String>[
      for (final name in kPickupCodeIcons.keys)
        if (!used.contains(name) && name != 'link') name,
    ];
    expect(unused, isEmpty, reason: '注册了但没人用的图标：$unused');
  });

  test('身份码与待取快递两组都非空（分区不会出现空标题）', () {
    final identity = <String>[
      for (final preset in kPickupCodePresets)
        if (pickupCodeIsIdentityCode(preset.icon)) preset.id,
    ];
    final parcels = <String>[
      for (final preset in kPickupCodePresets)
        if (!pickupCodeIsIdentityCode(preset.icon)) preset.id,
    ];
    expect(identity, isNotEmpty, reason: '「出示身份码」分区会空着');
    expect(parcels, isNotEmpty, reason: '「查待取快递」分区会空着');
    expect(identity.length + parcels.length, kPickupCodePresets.length);
  });

  test('全部包名去重后覆盖每条入口的兜底应用', () {
    final all = pickupCodeAllPackages();
    expect(all.toSet().length, all.length, reason: '包名列表有重复');
    for (final preset in kPickupCodePresets) {
      for (final package in preset.appPackages) {
        expect(
          all.contains(package),
          isTrue,
          reason: '${preset.id} 的包名 $package 没进汇总表',
        );
      }
    }
  });

  test('未知图标名回落默认图标，不抛', () {
    expect(pickupCodeIconFor('no_such_icon'), isNotNull);
    expect(pickupCodeIsIdentityCode('no_such_icon'), isFalse);
  });
}
