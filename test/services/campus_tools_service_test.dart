import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/domain/campus_tool_presets.dart';
import 'package:university_timetable/models/campus_tool_entry.dart';
import 'package:university_timetable/services/campus_tools_service.dart';

/// 持久化契约：空 / 坏 / 半坏三种数据都不许让页面变成空白。
///
/// 这里刻意**不**断言具体预置条数（那是数据表自己的事，见 presets 测试），
/// 只比较相对关系，改预置表不会误伤本文件。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('首次使用（没有键）回落到默认预设', () async {
    final entries = await CampusToolsService.load();
    expect(entries.length, kCampusToolPresets.length);
    expect(
      entries.map((entry) => entry.id),
      kCampusToolPresets.map((preset) => preset.id),
    );
  });

  test('保存后能原样读回（含停用 / clearTask / 自定义标题）', () async {
    final custom = <CampusToolEntry>[
      const CampusToolEntry(
        id: 'user-entry',
        title: '我的入口',
        icon: 'wifi',
        links: <CampusToolLink>[
          CampusToolLink(uri: 'http://10.0.0.1/login'),
        ],
        webUri: 'https://example.com/fallback',
        clearTask: true,
        enabled: false,
      ),
    ];
    expect(await CampusToolsService.save(custom), isTrue);
    final loaded = await CampusToolsService.load();
    expect(loaded.length, 1);
    final entry = loaded.single;
    expect(entry.id, 'user-entry');
    expect(entry.title, '我的入口');
    expect(entry.icon, 'wifi');
    expect(entry.links.single.uri, 'http://10.0.0.1/login');
    expect(entry.webUri, 'https://example.com/fallback');
    expect(entry.clearTask, isTrue);
    expect(entry.enabled, isFalse);
  });

  test('坏 JSON 回落到默认预设（不是空列表）', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      CampusToolsService.preferenceKey: '{not json',
    });
    final entries = await CampusToolsService.load();
    expect(entries.length, kCampusToolPresets.length);
  });

  test('解析成功但一条都不剩，也回落到默认预设', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      CampusToolsService.preferenceKey: jsonEncode(<Object?>['junk', 42]),
    });
    final entries = await CampusToolsService.load();
    expect(entries.length, kCampusToolPresets.length);
  });

  test('半坏数据：坏条目丢弃，好条目保留', () async {
    final raw = jsonEncode(<String, Object?>{
      'version': 1,
      'entries': <Object?>[
        <String, Object?>{'id': 'good', 'title': '好的'},
        'junk',
        <String, Object?>{'title': '没有 id'},
        <String, Object?>{'id': 'good', 'title': '重复 id'},
      ],
    });
    SharedPreferences.setMockInitialValues(<String, Object>{
      CampusToolsService.preferenceKey: raw,
    });
    final entries = await CampusToolsService.load();
    expect(entries.map((entry) => entry.id), <String>['good']);
    expect(entries.single.title, '好的');
  });

  test('兼容纯数组形状的旧载荷', () async {
    final raw = jsonEncode(<Object?>[
      <String, Object?>{'id': 'plain-array', 'title': 'A'},
    ]);
    SharedPreferences.setMockInitialValues(<String, Object>{
      CampusToolsService.preferenceKey: raw,
    });
    final entries = await CampusToolsService.load();
    expect(entries.single.id, 'plain-array');
  });

  test('写入的载荷带版本号，且 entries 是数组', () async {
    await CampusToolsService.save(campusToolDefaultEntries());
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(CampusToolsService.preferenceKey);
    expect(raw, isNotNull);
    final decoded = jsonDecode(raw!) as Map<String, dynamic>;
    expect(decoded['version'], CampusToolsService.schemaVersion);
    expect(decoded['entries'], isA<List<dynamic>>());
    expect(
      (decoded['entries'] as List<dynamic>).length,
      kCampusToolPresets.length,
    );
  });

  test('clear 后回到默认预设', () async {
    await CampusToolsService.save(const <CampusToolEntry>[
      CampusToolEntry(id: 'only-one'),
    ]);
    expect((await CampusToolsService.load()).length, 1);
    expect(await CampusToolsService.clear(), isTrue);
    expect(
      (await CampusToolsService.load()).length,
      kCampusToolPresets.length,
    );
  });
}
