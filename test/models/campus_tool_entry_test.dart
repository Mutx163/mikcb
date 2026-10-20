import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/campus_tool_entry.dart';

/// 模型层契约：序列化往返 + 坏数据逐条丢弃（不是整份判死）。
void main() {
  CampusToolEntry sample() => const CampusToolEntry(
    id: 'demo',
    title: '演示',
    icon: 'parcel',
    links: <CampusToolLink>[
      CampusToolLink(uri: 'demo://a', package: 'com.demo.app'),
      CampusToolLink(uri: 'https://demo.example/x'),
    ],
    appPackages: <String>['com.demo.app'],
    webUri: 'https://demo.example/y',
    clearTask: true,
    enabled: false,
  );

  test('JSON 往返不丢字段', () {
    final decoded = CampusToolEntry.tryParse(
      jsonDecode(jsonEncode(sample().toJson())),
    );
    expect(decoded, isNotNull);
    final entry = decoded!;
    expect(entry.id, 'demo');
    expect(entry.title, '演示');
    expect(entry.icon, 'parcel');
    expect(entry.links.length, 2);
    expect(entry.links.first.package, 'com.demo.app');
    expect(entry.links.last.package, isNull);
    expect(entry.appPackages, <String>['com.demo.app']);
    expect(entry.webUri, 'https://demo.example/y');
    expect(entry.clearTask, isTrue);
    expect(entry.enabled, isFalse);
  });

  test('editableLine 编码/解码对称：包名|链接', () {
    const link = CampusToolLink(uri: 'a://b?c=1', package: 'com.a.b');
    expect(link.editableLine, 'com.a.b|a://b?c=1');
    const plain = CampusToolLink(uri: 'a://b');
    expect(plain.editableLine, 'a://b');
  });

  test('缺 id / 非对象 / links 全坏时返回 null', () {
    expect(CampusToolEntry.tryParse(<String, Object?>{}), isNull);
    expect(CampusToolEntry.tryParse('x'), isNull);
    expect(CampusToolEntry.tryParse(null), isNull);
    expect(
      CampusToolEntry.tryParse(<String, Object?>{
        'id': '  ',
      }),
      isNull,
    );
  });

  test('未知字段与错类型字段被忽略，不炸整条', () {
    final entry = CampusToolEntry.tryParse(<String, Object?>{
      'id': 'x',
      'title': 42,
      'icon': null,
      'links': <Object?>['a://b', 7, <String, Object?>{'uri': 'c://d'}],
      'appPackages': <Object?>['com.a.b', 3, 'com.a.b'],
      'webUri': 9,
      'clearTask': 'yes',
      'enabled': null,
      'unknown': 'ignored',
    });
    expect(entry, isNotNull);
    expect(entry!.title, '');
    expect(entry.icon, kCampusToolDefaultIconName);
    expect(entry.links.length, 2);
    expect(entry.appPackages, <String>['com.a.b']);
    expect(entry.webUri, isNull);
    expect(entry.clearTask, isFalse);
    expect(entry.enabled, isTrue);
  });

  test('normalizeList 丢坏项、按 id 去重、保持顺序', () {
    final entries = CampusToolEntry.normalizeList(<Object?>[
      <String, Object?>{'id': 'a', 'title': 'A'},
      'junk',
      <String, Object?>{'id': 'a', 'title': 'duplicate'},
      <String, Object?>{'id': 'b'},
    ]);
    expect(entries.map((entry) => entry.id), <String>['a', 'b']);
    expect(entries.first.title, 'A');
    expect(CampusToolEntry.normalizeList('nope'), isEmpty);
  });

  test('targetCount 把链接 / 应用 / 网页都算进去；空串网页不算', () {
    expect(sample().targetCount, 4);
    expect(
      sample()
          .copyWith(webUri: '   ')
          .targetCount,
      3,
    );
    expect(
      const CampusToolEntry(id: 'empty').hasTarget,
      isFalse,
    );
  });

  test('copyWith 只换传入字段', () {
    final updated = sample().copyWith(enabled: true, title: '新名字');
    expect(updated.enabled, isTrue);
    expect(updated.title, '新名字');
    expect(updated.links.length, 2);
    expect(updated.id, 'demo');
  });
}
