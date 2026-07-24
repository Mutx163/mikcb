import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/warehouse_macro_models.dart';

void main() {
  group('sanitizeWarehouseScriptPageUrl', () {
    test('keeps stable path and drops session query params', () {
      final sanitized = sanitizeWarehouseScriptPageUrl(
        'https://jw.example.edu/jsxsd/xskb/xskb_list.do?xnxq01id=2025-2026-2&ticket=abc&token=xyz',
      );
      expect(sanitized, isNotNull);
      expect(sanitized, contains('xskb_list.do'));
      expect(sanitized, contains('xnxq01id=2025-2026-2'));
      expect(sanitized, isNot(contains('ticket=')));
      expect(sanitized, isNot(contains('token=')));
    });

    test('strips path-embedded jsessionid', () {
      final sanitized = sanitizeWarehouseScriptPageUrl(
        'https://jw.example.edu/jsxsd/xskb/xskb_list.do;jsessionid=DEADBEEF',
      );
      expect(sanitized, 'https://jw.example.edu/jsxsd/xskb/xskb_list.do');
    });

    test('rejects empty or invalid urls', () {
      expect(sanitizeWarehouseScriptPageUrl(null), isNull);
      expect(sanitizeWarehouseScriptPageUrl(''), isNull);
      expect(sanitizeWarehouseScriptPageUrl('not-a-url'), isNull);
      expect(sanitizeWarehouseScriptPageUrl('ftp://example.com/a'), isNull);
    });
  });

  group('buildAcceleratedMacroSteps', () {
    test('keeps login steps and replaces post-login clicks with navigate', () {
      final originalSteps = <MacroStep>[
        MacroStep.fillField(
          selector: '#username',
          value: 'student',
          fieldType: 'username',
        ),
        MacroStep.waitForManualInput(
          'manual_input_password',
          fieldType: 'password',
        ),
        MacroStep.click('#login'),
        MacroStep.delay(800),
        MacroStep.click('#menu-schedule'),
        MacroStep.delay(800),
        MacroStep.click('#semester-theory'),
        MacroStep.delay(800),
      ];

      final accelerated = buildAcceleratedMacroSteps(
        originalSteps,
        scriptPageUrl: 'https://jw.example.edu/jsxsd/xskb/xskb_list.do',
        importUrl: 'https://jw.example.edu/jsxsd/',
      );

      expect(accelerated.length, lessThan(originalSteps.length));
      expect(accelerated.first.type, MacroStepType.fillField);
      expect(
        accelerated.any((step) => step.type == MacroStepType.navigate),
        isTrue,
      );
      expect(
        accelerated
            .where((step) => step.type == MacroStepType.navigate)
            .single
            .value,
        'https://jw.example.edu/jsxsd/xskb/xskb_list.do',
      );
      // Intermediate menu clicks after login should be dropped.
      expect(
        accelerated.where((step) => step.selector == '#menu-schedule'),
        isEmpty,
      );
    });

    test('returns original steps when scriptPageUrl is missing', () {
      final originalSteps = <MacroStep>[
        MacroStep.click('#a'),
        MacroStep.click('#b'),
        MacroStep.click('#c'),
      ];
      final accelerated = buildAcceleratedMacroSteps(
        originalSteps,
        scriptPageUrl: null,
      );
      expect(identical(accelerated, originalSteps), isTrue);
    });

    test(
      'legacy macros without scriptPageUrl still drop post-login clicks',
      () {
        final originalSteps = <MacroStep>[
          MacroStep.fillField(
            selector: '#username',
            value: 'student',
            fieldType: 'username',
          ),
          MacroStep.waitForManualInput(
            'manual_input_password',
            fieldType: 'password',
          ),
          MacroStep.click('#login'),
          MacroStep.delay(800),
          MacroStep.click('#menu-schedule'),
          MacroStep.delay(800),
          MacroStep.click('#semester-theory'),
          MacroStep.delay(800),
        ];

        final accelerated = buildAcceleratedMacroSteps(
          originalSteps,
          scriptPageUrl: null,
          importUrl: 'https://jw.example.edu/jsxsd/',
        );

        expect(accelerated.length, lessThan(originalSteps.length));
        expect(
          accelerated.any((step) => step.selector == '#menu-schedule'),
          isFalse,
        );
        expect(
          accelerated.any((step) => step.type == MacroStepType.navigate),
          isFalse,
        );
        expect(accelerated.last.type, MacroStepType.delay);
      },
    );

    test('returns original steps when script page equals import entry', () {
      final originalSteps = <MacroStep>[
        MacroStep.fillField(
          selector: '#username',
          value: 'student',
          fieldType: 'username',
        ),
        MacroStep.click('#login'),
        MacroStep.delay(800),
        MacroStep.click('#extra-menu'),
        MacroStep.delay(800),
      ];
      final sameUrl = 'https://jw.example.edu/jsxsd/';
      final accelerated = buildAcceleratedMacroSteps(
        originalSteps,
        scriptPageUrl: sameUrl,
        importUrl: sameUrl,
      );
      // Same entry/script URL still drops redundant post-login clicks.
      expect(accelerated.length, lessThan(originalSteps.length));
      expect(
        accelerated.any((step) => step.selector == '#extra-menu'),
        isFalse,
      );
    });
  });

  group('WarehouseMacroRecord scriptPageUrl persistence', () {
    test('round-trips scriptPageUrl through json', () {
      final now = DateTime(2026, 7, 24);
      final record = WarehouseMacroRecord(
        schoolId: 'cqcst',
        adapterId: 'CQCST_01',
        schoolName: '重庆城市科技',
        adapterName: '强智',
        importUrl: 'http://jw.cqcst.edu.cn/cqdxcskjxy_jsxsd/',
        schoolResourceFolder: 'CQCST',
        adapterAssetJsPath: 'cqcst_01.js',
        steps: const [],
        createdAt: now,
        updatedAt: now,
        scriptPageUrl:
            'http://jw.cqcst.edu.cn/cqdxcskjxy_jsxsd/xskb/xskb_list.do?ticket=drop-me',
      );

      final restored = WarehouseMacroRecord.fromJson(record.toJson());
      expect(
        restored.scriptPageUrl,
        'http://jw.cqcst.edu.cn/cqdxcskjxy_jsxsd/xskb/xskb_list.do',
      );
    });
  });
}
