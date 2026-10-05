import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/warehouse_macro_models.dart';
import 'package:university_timetable/services/warehouse_macro_service.dart';

/// 回归钉（2026-10-05 审查第 14 轮）：宏目录（索引）与记录本体的走偏。
///
/// 目录只是"去哪儿找"，本体才是数据。旧实现对坏目录一律当"一个宏都没有"
/// （`_loadIndexList` 返回 `const []`），于是下一次保存会把"只剩自己一条"的
/// 目录写回去：其它宏的本体还在磁盘上，却再也不会出现在列表里，也没有任何
/// 路径能找回；`exportAllMacros` 同样按目录导出，残缺目录会跟着进云快照，
/// 把别的设备一起刷成"没这些宏"。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  WarehouseMacroRecord recordFor(String schoolId, String adapterId) {
    final now = DateTime(2024, 1, 2, 3, 4, 5);
    return WarehouseMacroRecord(
      schoolId: schoolId,
      adapterId: adapterId,
      schoolName: '测试学校',
      adapterName: '测试教务',
      importUrl: 'https://example.com/login',
      schoolResourceFolder: schoolId,
      adapterAssetJsPath: 'adapter.js',
      steps: const [],
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> corruptIndex() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      WarehouseMacroRecord.indexKey,
      jsonEncode({'not': 'a list'}),
    );
  }

  Future<void> writeIndex(List<WarehouseMacroIndexEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      WarehouseMacroRecord.indexKey,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> seedThreeMacros() async {
    final service = WarehouseMacroService();
    await service.saveMacro(recordFor('school-1', 'adapter-a'));
    await service.saveMacro(recordFor('school-1', 'adapter-b'));
    await service.saveMacro(recordFor('school-2', 'adapter-c'));
  }

  List<String> keysOf(List<WarehouseMacroIndexEntry> entries) => entries
      .map((e) => '${e.schoolId}/${e.adapterId}')
      .toList()
    ..sort();

  test('目录坏了：再保存一条不能把其它宏从列表里抹掉', () async {
    await seedThreeMacros();
    await corruptIndex();

    final service = WarehouseMacroService();
    await service.saveMacro(recordFor('school-3', 'adapter-d'));

    expect(
      keysOf(await service.getAllMacroEntries()),
      ['school-1/adapter-a', 'school-1/adapter-b', 'school-2/adapter-c', 'school-3/adapter-d'],
    );
  });

  test('目录坏了：只读取列表也能自愈，并把重建结果落盘', () async {
    await seedThreeMacros();
    await corruptIndex();

    final service = WarehouseMacroService();
    expect(
      keysOf(await service.getAllMacroEntries()),
      ['school-1/adapter-a', 'school-1/adapter-b', 'school-2/adapter-c'],
    );

    final prefs = await SharedPreferences.getInstance();
    final repaired =
        jsonDecode(prefs.getString(WarehouseMacroRecord.indexKey)!)
            as List<dynamic>;
    expect(repaired.length, 3);
  });

  test('本体写成功但目录写失败（目录少一条）：列表仍然认它', () async {
    // 模拟 saveMacro 两次 await 之间被打断：school-2 的本体在，目录里没有。
    await seedThreeMacros();
    await writeIndex([
      WarehouseMacroIndexEntry(
        schoolId: 'school-1',
        adapterId: 'adapter-a',
        updatedAt: DateTime(2024, 1, 2, 3, 4, 5),
      ),
      WarehouseMacroIndexEntry(
        schoolId: 'school-1',
        adapterId: 'adapter-b',
        updatedAt: DateTime(2024, 1, 2, 3, 4, 5),
      ),
    ]);

    final entries = await WarehouseMacroService().getAllMacroEntries();
    expect(
      keysOf(entries),
      ['school-1/adapter-a', 'school-1/adapter-b', 'school-2/adapter-c'],
    );
  });

  test('目录坏了时删除一条，不能顺手把其它条目一起清掉', () async {
    await seedThreeMacros();
    await corruptIndex();

    final service = WarehouseMacroService();
    await service.deleteMacro('school-1', 'adapter-a');

    expect(
      keysOf(await service.getAllMacroEntries()),
      ['school-1/adapter-b', 'school-2/adapter-c'],
    );
  });

  test('对照：真的没有宏时返回空列表，且不会凭空写一份目录', () async {
    SharedPreferences.setMockInitialValues({});
    final service = WarehouseMacroService();

    expect(await service.getAllMacroEntries(), isEmpty);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(WarehouseMacroRecord.indexKey), isFalse);
  });

  test('对照：目录是好的就不该反复回写', () async {
    await seedThreeMacros();
    final prefs = await SharedPreferences.getInstance();
    final before = prefs.getString(WarehouseMacroRecord.indexKey);

    await WarehouseMacroService().getAllMacroEntries();

    expect(prefs.getString(WarehouseMacroRecord.indexKey), before);
  });

  test('导入重复项不再产生两份目录条目', () async {
    final service = WarehouseMacroService();
    await service.importAllMacros([
      recordFor('school-1', 'adapter-a'),
      recordFor('school-1', 'adapter-a'),
      recordFor('school-2', 'adapter-b'),
    ]);

    final entries = await service.getAllMacroEntries();
    expect(entries, hasLength(2));
    expect(keysOf(entries), ['school-1/adapter-a', 'school-2/adapter-b']);
  });
}
