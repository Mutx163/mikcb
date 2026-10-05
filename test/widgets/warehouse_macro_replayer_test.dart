import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/warehouse_macro_replay_logic.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/warehouse_macro_models.dart';
import 'package:university_timetable/widgets/warehouse_macro_replayer.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('zh'));

  group('ensureMacroElementFound', () {
    test('throws when JavaScript reports missing element', () {
      expect(
        () => ensureMacroElementFound(
          '{"found":false,"selector":"#missing"}',
          '未找到点击元素: #missing',
        ),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('未找到点击元素: #missing'),
          ),
        ),
      );
    });

    test('does not throw for found element or non-json result', () {
      expect(
        () => ensureMacroElementFound(
          '{"found":true,"selector":"#login"}',
          '未找到点击元素: #login',
        ),
        returnsNormally,
      );
      expect(
        () => ensureMacroElementFound('true', '未找到点击元素: #login'),
        returnsNormally,
      );
    });

    test('平台把返回值按 JSON 编码送回时，也要真的判出元素缺失', () {
      // 这是 Android 上 evaluateJavascript 对 `JSON.stringify({...})` 的实际
      // 形态：外层带引号、内层引号转义。旧归一化只切首尾引号，留下
      // {\"found\":false,...}，jsonDecode 抛 FormatException 被当成「非 JSON
      // 忽略」，于是填充/点击没找到元素却一路当成功。
      const androidQuoted = r'"{\"found\":false,\"selector\":\"#user\"}"';
      expect(
        () => ensureMacroElementFound(
          normalizeWebScriptResult(androidQuoted),
          '未找到填充元素: #user',
        ),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('未找到填充元素: #user'),
          ),
        ),
      );
    });

    test('同样是编码返回值，found:true 不该误报', () {
      const androidQuotedOk = r'"{\"found\":true,\"tag\":\"INPUT\"}"';
      expect(
        () => ensureMacroElementFound(
          normalizeWebScriptResult(androidQuotedOk),
          '未找到填充元素: #user',
        ),
        returnsNormally,
      );
    });
  });

  group('shouldUseRememberedPasswordForManualStep', () {
    test('uses remembered password for explicit password manual steps', () {
      final step = MacroStep.waitForManualInput(
        '请手动输入密码；如已自动填充请直接继续',
        fieldType: 'password',
      );

      expect(
        shouldUseRememberedPasswordForManualStep(step, step.value!, l10n),
        isTrue,
      );
    });

    test('uses remembered password for legacy generic manual steps', () {
      const step = MacroStep(type: MacroStepType.waitForManualInput);

      expect(
        shouldUseRememberedPasswordForManualStep(
          step,
          l10n.macroReplayManualActionRequired,
          l10n,
        ),
        isTrue,
      );
    });

    test('does not use remembered password for captcha steps', () {
      final explicitCaptcha = MacroStep.waitForManualInput(
        '请手动输入验证码；完成后点击继续',
        fieldType: 'captcha',
      );
      const legacyCaptcha = MacroStep(
        type: MacroStepType.waitForManualInput,
        value: '请手动输入验证码；完成后点击继续',
      );

      expect(
        shouldUseRememberedPasswordForManualStep(
          explicitCaptcha,
          explicitCaptcha.value!,
          l10n,
        ),
        isFalse,
      );
      expect(
        shouldUseRememberedPasswordForManualStep(
          legacyCaptcha,
          legacyCaptcha.value!,
          l10n,
        ),
        isFalse,
      );
    });
  });
}
