import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/holiday_entry.dart';
import 'package:university_timetable/models/warehouse_macro_models.dart';
import 'package:university_timetable/services/holiday_service.dart';
import 'package:university_timetable/services/warehouse_macro_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HolidayService.saveCustomHolidays 写失败不再被吞', () {
    test('写成功后 loadCustomHolidays 能读回（回归锚点：曾整体 catch 吞写失败）',
        () async {
      SharedPreferences.setMockInitialValues({});
      final service = HolidayService();

      await service.saveCustomHolidays([
        HolidayEntry(
          // 十一假期（10 月 1 日）；day=1 是 DateTime 默认值故省略。
          date: DateTime(2026, 10),
          name: '自定义假期',
          type: HolidayType.vacation,
          groupId: 'g-1',
        ),
      ]);

      final loaded = await service.loadCustomHolidays();
      expect(loaded, isNotNull);
      expect(loaded, hasLength(1));
      expect(loaded!.single.name, '自定义假期');
    });

    test('底层写失败时异常向上抛，调用方可感知保存未成功', () async {
      // SharedPreferences mock 无法直接注入写失败；通过自定义HolidayEntry
      // 子类的 toJson 返回不可 JSON 序列化对象，让 jsonEncode 在序列化段
      // 必抛 JsonUnsupportedObjectError。写失败经 PR#19 的类型化包装
      // HolidayCustomSaveException 向上传播（cause 保留原始错误供归因），
      // 断言锚定「不吞 + 归因链完整」两个语义。
      SharedPreferences.setMockInitialValues({});
      final service = HolidayService();

      await expectLater(
        service.saveCustomHolidays([
          _UnserializableEntry(
            date: DateTime(2026, 10),
            name: 'x',
            type: HolidayType.vacation,
            groupId: 'g',
          ),
        ]),
        throwsA(
          isA<HolidayCustomSaveException>().having(
            (e) => e.cause,
            'cause',
            isA<JsonUnsupportedObjectError>(),
          ),
        ),
      );
    });
  });

  group('WarehouseMacroService.importAllMacros 不再先清库', () {
    test('导入成功后旧记录被替换、新记录与索引完整落盘', () async {
      SharedPreferences.setMockInitialValues({
        'warehouse_macro_record_old-school_old-adapter': jsonEncode(
          WarehouseMacroRecord(
            schoolId: 'old-school',
            adapterId: 'old-adapter',
            schoolName: '',
            adapterName: '',
            importUrl: '',
            schoolResourceFolder: '',
            adapterAssetJsPath: '',
            steps: const [],
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ).toJson(),
        ),
      });
      final service = WarehouseMacroService();

      final incoming = WarehouseMacroRecord(
        schoolId: 'school-a',
        adapterId: 'adapter-1',
        schoolName: '学校A',
        adapterName: '适配器1',
        importUrl: 'https://example.com',
        schoolResourceFolder: '',
        adapterAssetJsPath: '',
        steps: const [],
        createdAt: DateTime(2026, 8, 31, 9),
        updatedAt: DateTime(2026, 8, 31, 9),
      );
      await service.importAllMacros([incoming]);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(
          'warehouse_macro_record_school-a_adapter-1',
        ),
        isNotNull,
      );
      expect(
        prefs.getString('warehouse_macro_record_old-school_old-adapter'),
        isNull,
      );
      // 索引与记录一致（先清后写的旧实现中途失败会丢索引）。
      final index = prefs.getString(WarehouseMacroRecord.indexKey);
      expect(index, isNotNull);
      final decoded = jsonDecode(index!) as List<dynamic>;
      expect(decoded, hasLength(1));
      final firstEntry = decoded.first as Map<String, dynamic>;
      expect(firstEntry['schoolId'], 'school-a');
    });

    test('空导入列表仍清空本地记录并落空索引', () async {
      SharedPreferences.setMockInitialValues({
        'warehouse_macro_record_s_a': '{}',
        WarehouseMacroRecord.indexKey: '[]',
      });
      final service = WarehouseMacroService();

      await service.importAllMacros(const []);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('warehouse_macro_record_s_a'), isNull);
      expect(prefs.getString(WarehouseMacroRecord.indexKey), '[]');
    });
  });
}

/// toJson 返回不可 JSON 序列化对象的自定义假期条目。
///
/// saveCustomHolidays 对 entries 走 jsonEncode；普通 HolidayEntry 的
/// toJson 全是基本类型，无法在 mock SharedPreferences 上注入写失败，
/// 用该子类让序列化段确定性抛 JsonUnsupportedObjectError。
class _UnserializableEntry extends HolidayEntry {
  const _UnserializableEntry({
    required super.date,
    required super.name,
    required super.type,
    super.groupId,
  });

  @override
  Map<String, dynamic> toJson() => {
    // DateTime 实例本身不可被 jsonEncode 直接序列化（day=1 默认值省略）。
    'date': DateTime(2026, 10),
    'name': 'x',
    'type': HolidayType.vacation.value,
    'groupId': 'g',
  };
}
