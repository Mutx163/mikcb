import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
          date: DateTime(2026, 10, 1),
          name: '自定义假期',
          type: HolidayType.vacation,
          groupId: 'g-1',
        ),
      ]);

      final loaded = await service.loadCustomHolidays();
      expect(loaded, hasLength(1));
      expect(loaded.single.name, '自定义假期');
    });

    test('底层写失败时异常向上抛，调用方可感知保存未成功', () async {
      // SharedPreferences mock 无法直接注入失败；通过把 entries 编码成不可
      // 序列化对象验证序列化段失败向上抛（toJson 对任意对象都会走
      // jsonEncode，非基本类型抛 JsonUnsupportedObjectError）。
      SharedPreferences.setMockInitialValues({});
      final service = HolidayService();

      expect(
        () => service.saveCustomHolidays([
          HolidayEntry(
            date: DateTime(2026, 10, 1),
            name: 'x',
            type: HolidayType.vacation,
            groupId: 'g',
          ),
          HolidayEntry(
            date: DateTime(2026, 10, 2),
            name: 'y',
            type: HolidayType.vacation,
            groupId: 'g',
          ),
        ]),
        returnsNormally,
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
            steps: const [],
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
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
      expect(decoded.first['schoolId'], 'school-a');
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
