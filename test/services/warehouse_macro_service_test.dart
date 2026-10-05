import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/warehouse_macro_models.dart';
import 'package:university_timetable/services/warehouse_macro_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('sanitizes legacy password values when loading macros', () async {
    const schoolId = 'school-1';
    const adapterId = 'adapter-1';
    final key = WarehouseMacroRecord.storageKey(schoolId, adapterId);
    SharedPreferences.setMockInitialValues({
      key: jsonEncode({
        'schoolId': schoolId,
        'adapterId': adapterId,
        'schoolName': '测试学校',
        'adapterName': '测试教务',
        'importUrl': 'https://example.com/login',
        'schoolResourceFolder': schoolId,
        'adapterAssetJsPath': 'adapter.js',
        'steps': [
          {
            'type': 'fillField',
            'fieldType': 'password',
            'selector': '#password',
            'value': 'legacy-secret',
          },
        ],
        'dialogResponses': <String, dynamic>{},
        'createdAt': DateTime(2024).toIso8601String(),
        'updatedAt': DateTime(2024).toIso8601String(),
        'successfulImportCount': 0,
      }),
    });

    final service = WarehouseMacroService();
    final restored = await service.getMacro(schoolId, adapterId);
    final prefs = await SharedPreferences.getInstance();
    final persistedRaw = prefs.getString(key);

    expect(restored, isNotNull);
    expect(restored!.steps, hasLength(1));
    expect(restored.steps.first.type, MacroStepType.waitForManualInput);
    expect(restored.steps.first.value, contains('manual_input_password'));
    expect(persistedRaw, isNotNull);
    expect(persistedRaw, isNot(contains('legacy-secret')));
  });

  test('读宏时不会因为解析丢了步骤就把残缺版本写回磁盘', () async {
    // getMacro 会在读路径上把重新编码的结果写回磁盘，本意是顺手洗掉旧记录里
    // 存过的密码（上一条测试就是它）。但它原先无从分辨「只是脱敏」和「解析真的
    // 丢了步骤」：宏里只要有一条认不出的步骤（版本更替留下的、别的工具导出的），
    // 打开一次宏列表就会把「少了几步」的残缺版本永久存下来，升级 App 也回不来。
    const schoolId = 'school-1';
    const adapterId = 'adapter-1';
    final key = WarehouseMacroRecord.storageKey(schoolId, adapterId);
    SharedPreferences.setMockInitialValues({
      key: jsonEncode({
        'schoolId': schoolId,
        'adapterId': adapterId,
        'schoolName': '测试学校',
        'adapterName': '测试教务',
        'importUrl': 'https://example.com/login',
        'schoolResourceFolder': schoolId,
        'adapterAssetJsPath': 'adapter.js',
        'steps': [
          {'type': 'click', 'selector': '#login'},
          {'type': 'quantum_leap', 'selector': '#from-a-newer-version'},
        ],
        'dialogResponses': <String, dynamic>{},
        'createdAt': DateTime(2024).toIso8601String(),
        'updatedAt': DateTime(2024).toIso8601String(),
        'successfulImportCount': 0,
      }),
    });

    final service = WarehouseMacroService();
    final restored = await service.getMacro(schoolId, adapterId);
    final prefs = await SharedPreferences.getInstance();
    final persistedRaw = prefs.getString(key);

    expect(restored, isNotNull);
    // 内存里照旧按既有口径丢掉认不出的那条 —— 回放行为不变（不会伪造成 delay）。
    expect(restored!.steps, hasLength(1));
    expect(restored.steps.single.type, MacroStepType.click);
    // 磁盘上必须原样保留，留给以后能认识它的版本。
    expect(persistedRaw, isNotNull);
    expect(persistedRaw, contains('quantum_leap'));
    expect(persistedRaw, contains('#from-a-newer-version'));
  });

  test('只是脱敏差异时仍照旧回写（不能把安全清洗一起关掉）', () async {
    const schoolId = 'school-1';
    const adapterId = 'adapter-2';
    final key = WarehouseMacroRecord.storageKey(schoolId, adapterId);
    SharedPreferences.setMockInitialValues({
      key: jsonEncode({
        'schoolId': schoolId,
        'adapterId': adapterId,
        'schoolName': '测试学校',
        'adapterName': '测试教务',
        'importUrl': 'https://example.com/login#/schedule',
        'schoolResourceFolder': schoolId,
        'adapterAssetJsPath': 'adapter.js',
        'steps': [
          {
            'type': 'fillField',
            'fieldType': 'password',
            'selector': '#password',
            'value': 'still-a-secret',
          },
          {'type': 'click', 'selector': '#submit'},
        ],
        'dialogResponses': <String, dynamic>{},
        'createdAt': DateTime(2024).toIso8601String(),
        'updatedAt': DateTime(2024).toIso8601String(),
        'successfulImportCount': 0,
      }),
    });

    final service = WarehouseMacroService();
    await service.getMacro(schoolId, adapterId);
    final prefs = await SharedPreferences.getInstance();
    final persistedRaw = prefs.getString(key)!;

    // 敏感值是被「转换成等待手动输入」这一步洗掉的，不算丢步骤，所以回写照常发生。
    expect(persistedRaw, isNot(contains('still-a-secret')));
    // 顺带钉住新的 URL 口径：hash 路由的 fragment 不再被脱敏顺手抹掉。
    expect(persistedRaw, contains('#/schedule'));
  });

  test('saves, indexes, reads, and deletes macro records', () async {
    final service = WarehouseMacroService();
    final now = DateTime(2024, 1, 2, 3, 4, 5);
    final record = WarehouseMacroRecord(
      schoolId: 'school-1',
      adapterId: 'adapter-1',
      schoolName: '测试学校',
      adapterName: '测试教务',
      importUrl: 'https://example.com/login',
      schoolResourceFolder: 'school-1',
      adapterAssetJsPath: 'adapter.js',
      steps: [
        MacroStep.fillField(
          selector: '#username',
          value: 'student',
          fieldType: 'username',
        ),
        MacroStep.click('#login'),
      ],
      createdAt: now,
      updatedAt: now,
    );

    await service.saveMacro(record);

    expect(await service.hasMacro('school-1', 'adapter-1'), isTrue);
    final restored = await service.getMacro('school-1', 'adapter-1');
    expect(restored?.schoolName, '测试学校');
    expect(restored?.steps, hasLength(2));

    final entries = await service.getAllMacroEntries();
    expect(entries, hasLength(1));
    expect(entries.single.schoolId, 'school-1');
    expect(entries.single.adapterId, 'adapter-1');

    await service.deleteMacro('school-1', 'adapter-1');

    expect(await service.hasMacro('school-1', 'adapter-1'), isFalse);
    expect(await service.getMacro('school-1', 'adapter-1'), isNull);
    expect(await service.getAllMacroEntries(), isEmpty);
  });

  test('persists optional useDesktopMode', () async {
    final service = WarehouseMacroService();
    final now = DateTime(2024, 1, 2, 3, 4, 5);
    final record = WarehouseMacroRecord(
      schoolId: 'school-1',
      adapterId: 'adapter-1',
      schoolName: '测试学校',
      adapterName: '测试教务',
      importUrl: 'https://example.com/login',
      schoolResourceFolder: 'school-1',
      adapterAssetJsPath: 'adapter.js',
      steps: const [],
      createdAt: now,
      updatedAt: now,
      useDesktopMode: false,
    );

    await service.saveMacro(record);

    final restored = await service.getMacro('school-1', 'adapter-1');
    expect(restored?.useDesktopMode, isFalse);
  });
}
