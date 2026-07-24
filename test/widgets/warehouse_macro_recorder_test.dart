import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/warehouse_macro_models.dart';
import 'package:university_timetable/widgets/warehouse_macro_recorder.dart';

void main() {
  group('MacroRecordingConverter', () {
    test('deduplicates live bridge and dump events', () {
      final rawEvents = <Map<String, dynamic>>[
        {
          'eventType': 'input',
          'selector': '#username',
          'value': 'student',
          'fieldType': 'username',
          'timestamp': 1000,
        },
        {
          'eventType': 'input',
          'selector': '#username',
          'value': 'student',
          'fieldType': 'username',
          'timestamp': 1000,
        },
        {
          'eventType': 'click',
          'selector': '#login',
          'value': '登录',
          'fieldType': 'button',
          'timestamp': 1200,
        },
        {
          'eventType': 'click',
          'selector': '#login',
          'value': '登录',
          'fieldType': 'button',
          'timestamp': 1200,
        },
      ];

      final steps = MacroRecordingConverter.convert(rawEvents);

      expect(steps, hasLength(3));
      expect(steps[0].type, MacroStepType.fillField);
      expect(steps[0].selector, '#username');
      expect(steps[0].value, 'student');
      expect(steps[1].type, MacroStepType.click);
      expect(steps[1].selector, '#login');
      expect(steps[2].type, MacroStepType.delay);
      expect(steps[2].waitMs, 800);
    });

    test('collapses sequential keystrokes into one fillField', () {
      final rawEvents = <Map<String, dynamic>>[
        {
          'eventType': 'input',
          'selector': '#username',
          'value': 's',
          'fieldType': 'username',
          'timestamp': 1000,
        },
        {
          'eventType': 'input',
          'selector': '#username',
          'value': 'st',
          'fieldType': 'username',
          'timestamp': 1050,
        },
        {
          'eventType': 'input',
          'selector': '#username',
          'value': 'stu',
          'fieldType': 'username',
          'timestamp': 1100,
        },
        {
          'eventType': 'click',
          'selector': '#login',
          'value': '登录',
          'fieldType': 'button',
          'timestamp': 1500,
        },
      ];

      final steps = MacroRecordingConverter.convert(rawEvents);

      final fillSteps = steps
          .where((step) => step.type == MacroStepType.fillField)
          .toList();
      expect(fillSteps, hasLength(1));
      expect(fillSteps.single.selector, '#username');
      expect(fillSteps.single.value, 'stu');
    });

    test('compactMacroFillSteps merges legacy per-keystroke fills', () {
      final steps = compactMacroFillSteps([
        MacroStep.fillField(
          selector: '#username',
          value: 'a',
          fieldType: 'username',
        ),
        MacroStep.delay(200),
        MacroStep.fillField(
          selector: '#username',
          value: 'ab',
          fieldType: 'username',
        ),
        MacroStep.fillField(
          selector: '#username',
          value: 'abc',
          fieldType: 'username',
        ),
        MacroStep.click('#login'),
      ]);

      expect(steps, hasLength(2));
      expect(steps[0].type, MacroStepType.fillField);
      expect(steps[0].value, 'abc');
      expect(steps[1].type, MacroStepType.click);
    });

    test('does not produce fill steps with password or captcha values', () {
      final rawEvents = <Map<String, dynamic>>[
        {
          'eventType': 'input',
          'selector': '#password',
          'value': 'secret-password',
          'fieldType': 'password',
          'timestamp': 1000,
        },
        {
          'eventType': 'input',
          'selector': '#captcha',
          'value': '1234',
          'fieldType': 'captcha',
          'timestamp': 2000,
        },
      ];

      final steps = MacroRecordingConverter.convert(rawEvents);

      expect(steps, hasLength(2));
      expect(
        steps.map((step) => step.type),
        everyElement(MacroStepType.waitForManualInput),
      );
      expect(steps.any((step) => step.value == 'secret-password'), isFalse);
      expect(steps.any((step) => step.value == '1234'), isFalse);
      expect(steps.first.fieldType, 'password');
      expect(steps.first.selector, '#password');
      expect(steps.first.value, contains('manual_input_password'));
      expect(steps.last.fieldType, 'captcha');
      expect(steps.last.selector, '#captcha');
      expect(steps.last.value, contains('manual_input_captcha'));
    });

    test('creates one manual-input step per sensitive selector', () {
      final rawEvents = <Map<String, dynamic>>[
        {
          'eventType': 'input',
          'selector': '#password',
          'value': '',
          'fieldType': 'password',
          'timestamp': 1000,
        },
        {
          'eventType': 'change',
          'selector': '#password',
          'value': '',
          'fieldType': 'password',
          'timestamp': 1100,
        },
        {
          'eventType': 'input',
          'selector': '#captcha',
          'value': '',
          'fieldType': 'captcha',
          'timestamp': 1200,
        },
        {
          'eventType': 'change',
          'selector': '#captcha',
          'value': '',
          'fieldType': 'captcha',
          'timestamp': 1300,
        },
      ];

      final steps = MacroRecordingConverter.convert(rawEvents);

      expect(
        steps.where((step) => step.type == MacroStepType.waitForManualInput),
        hasLength(2),
      );
      expect(
        steps.where(
          (step) => step.value?.contains('manual_input_password') ?? false,
        ),
        hasLength(1),
      );
      expect(
        steps.where(
          (step) => step.value?.contains('manual_input_captcha') ?? false,
        ),
        hasLength(1),
      );
    });

    test('submit adds click and longer navigation delay', () {
      final rawEvents = <Map<String, dynamic>>[
        {
          'eventType': 'submit',
          'selector': '#login-form',
          'fieldType': 'form',
          'timestamp': 1000,
        },
      ];

      final steps = MacroRecordingConverter.convert(rawEvents);

      expect(steps, hasLength(2));
      expect(steps[0].type, MacroStepType.click);
      expect(steps[0].selector, '#login-form');
      expect(steps[1].type, MacroStepType.delay);
      expect(steps[1].waitMs, 2500);
    });
  });

  group('warehouseDialogResponseKey', () {
    test('prefers dialogId when provided', () {
      final key = warehouseDialogResponseKey('singleSelection', {
        'dialogId': 'semester-picker',
        'title': '选择学期',
        'optionsJson': '["2024春","2024秋"]',
      });

      expect(key, 'singleSelection|id:semester-picker');
    });

    test('falls back to title and body when dialogId is absent', () {
      final key = warehouseDialogResponseKey('confirm', {
        'title': '确认导入',
        'message': '是否继续？',
      });

      expect(key, 'confirm|确认导入|是否继续？');
    });

    test('uses optionsJson as body fallback when message is absent', () {
      final key = warehouseDialogResponseKey('singleSelection', {
        'title': '选择学期',
        'optionsJson': '["2024春","2024秋"]',
      });

      expect(key, 'singleSelection|选择学期|["2024春","2024秋"]');
    });
  });

  group('WarehouseMacroRecord', () {
    test('round-trips optional useDesktopMode false', () {
      final record = WarehouseMacroRecord(
        schoolId: 's1',
        adapterId: 'a1',
        schoolName: 'School',
        adapterName: 'Adapter',
        importUrl: 'https://example.com',
        schoolResourceFolder: 's1',
        adapterAssetJsPath: 'a.js',
        steps: const [],
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        useDesktopMode: false,
      );

      final restored = WarehouseMacroRecord.fromJson(record.toJson());

      expect(restored.useDesktopMode, isFalse);
    });

    test('round-trips optional useDesktopMode true', () {
      final record = WarehouseMacroRecord(
        schoolId: 's1',
        adapterId: 'a1',
        schoolName: 'School',
        adapterName: 'Adapter',
        importUrl: 'https://example.com',
        schoolResourceFolder: 's1',
        adapterAssetJsPath: 'a.js',
        steps: const [],
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        useDesktopMode: true,
      );

      final restored = WarehouseMacroRecord.fromJson(record.toJson());

      expect(restored.useDesktopMode, isTrue);
    });

    test('legacy JSON without useDesktopMode stays null', () {
      final restored = WarehouseMacroRecord.fromJson({
        'schoolId': 's1',
        'adapterId': 'a1',
        'schoolName': 'School',
        'adapterName': 'Adapter',
        'importUrl': 'https://example.com',
        'schoolResourceFolder': 's1',
        'adapterAssetJsPath': 'a.js',
        'steps': <Map<String, dynamic>>[],
        'createdAt': DateTime(2024).toIso8601String(),
        'updatedAt': DateTime(2024).toIso8601String(),
      });

      expect(restored.useDesktopMode, isNull);
    });
  });

  group('MacroStep', () {
    test('does not serialize sensitive fill values', () {
      final json = MacroStep.fillField(
        selector: '#password',
        value: 'secret-password',
        fieldType: 'password',
      ).toJson();

      expect(json['fieldType'], 'password');
      expect(json['selector'], '#password');
      expect(json.containsKey('value'), isFalse);
    });

    test('manual password input keeps reason but not secret values', () {
      final json = MacroStep.waitForManualInput(
        'manual_input_password',
        selector: '#password',
        fieldType: 'password',
      ).toJson();

      expect(json['type'], 'waitForManualInput');
      expect(json['fieldType'], 'password');
      expect(json['selector'], '#password');
      expect(json['value'], contains('manual_input_password'));
      expect(json.toString(), isNot(contains('secret-password')));
    });

    test('migrates legacy sensitive fill steps to manual input', () {
      final step = MacroStep.fromJson({
        'type': 'fillField',
        'fieldType': 'password',
        'selector': '#password',
        'value': 'legacy-secret',
      });

      expect(step.type, MacroStepType.waitForManualInput);
      expect(step.fieldType, 'password');
      expect(step.selector, '#password');
      expect(step.value, contains('manual_input_password'));
      expect(step.toJson().toString(), isNot(contains('legacy-secret')));
    });
  });
}
