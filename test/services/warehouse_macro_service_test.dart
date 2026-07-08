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
