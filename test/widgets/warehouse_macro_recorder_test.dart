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

      expect(steps, hasLength(2));
      expect(steps[0].type, MacroStepType.fillField);
      expect(steps[0].selector, '#username');
      expect(steps[0].value, 'student');
      expect(steps[1].type, MacroStepType.click);
      expect(steps[1].selector, '#login');
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
      expect(steps.first.value, contains('密码'));
      expect(steps.last.fieldType, 'captcha');
      expect(steps.last.selector, '#captcha');
      expect(steps.last.value, contains('验证码'));
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
        steps.where((step) => step.value?.contains('密码') ?? false),
        hasLength(1),
      );
      expect(
        steps.where((step) => step.value?.contains('验证码') ?? false),
        hasLength(1),
      );
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
        '请手动输入密码；如已自动填充请直接继续',
        selector: '#password',
        fieldType: 'password',
      ).toJson();

      expect(json['type'], 'waitForManualInput');
      expect(json['fieldType'], 'password');
      expect(json['selector'], '#password');
      expect(json['value'], contains('密码'));
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
      expect(step.value, contains('密码'));
      expect(step.toJson().toString(), isNot(contains('legacy-secret')));
    });
  });
}
