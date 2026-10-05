import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/warehouse_macro_models.dart';

/// 回归钉（2026-10-02 审查第 9 轮，宏步骤类型的未知兜底）：
///
/// `MacroStep.fromJson` 对认不出的 `type` 用 `orElse: () => MacroStepType.delay`
/// （warehouse_macro_models.dart:108-111），于是**凭空多出一条本来不存在的步骤**：
/// 仓库下载的宏、别人分享的文件、或新版本写出的新步骤类型，在这版里会被变成
/// "等待 0 毫秒"的空步骤。两个后果：
/// 1. 回放时该步被静默跳过（少一次点击/导航），但步骤列表与"第 N 步"进度照旧，
///    用户看不出少做了什么；
/// 2. 更糟的是不可逆：`toStorageJson()` 会把 `type` 写成 `'delay'`，用户"另存为我的宏"
///    或应用一次，原始类型就永久丢了 —— 之后升级 App 也恢复不回来。
///
/// 上层 loader（同文件 :253-264）本来就按「坏条目整条丢弃、其余照常」处理
/// （`s is! Map → continue`、`catch (_) → continue`），所以正确做法是抛出去
/// 让它按既有口径丢弃，而不是伪造一条能 round-trip 的假步骤。
void main() {
  Map<String, dynamic> stepJson(Object type) => <String, dynamic>{
    'type': type,
    'selector': '#kb',
    'value': '2026-2027',
    'waitMs': 800,
  };

  test('未知步骤类型不再被伪造成交空的 delay', () {
    expect(
      () => MacroStep.fromJson(stepJson('waitForPageTitle')),
      throwsA(isA<FormatException>()),
    );
  });

  test('未知类型也不允许往返成一条看起来合法的步骤', () {
    // 修复前的行为：先被兜成 delay，再被 toStorageJson 写回 'delay'，
    // 原类型 'waitForPageTitle' 永久丢失。
    final step = MacroStep.fromJson(stepJson('delay'));
    expect(step.type, MacroStepType.delay);
    expect(step.toJson()['type'], 'delay');
    expect(step.waitMs, 800, reason: '已知类型的内容必须原样保留');
  });

  test('八个已知类型全部照常解析，不被新守卫误杀', () {
    for (final type in MacroStepType.values) {
      final step = MacroStep.fromJson(stepJson(type.name));
      expect(step.type, type, reason: '${type.name} 不该被拒');
      expect(step.selector, '#kb');
      expect(step.waitMs, 800);
    }
  });

  test('type 缺失或不是字符串同样按坏条目拒绝，不兜成 delay', () {
    expect(() => MacroStep.fromJson(<String, dynamic>{}), throwsA(isA<FormatException>()));
    expect(
      () => MacroStep.fromJson(stepJson(3)),
      throwsA(isA<FormatException>()),
    );
  });

  test('上层 loader 丢掉无法识别的步骤，其余步骤照常可用', () {
    final record = WarehouseMacroRecord.fromJson(<String, dynamic>{
      'schoolId': 's1',
      'adapterId': 'a1',
      'steps': <dynamic>[
        stepJson('navigate'),
        stepJson('waitForPageTitle'),
        stepJson('click'),
      ],
    });

    expect(record.steps.map((step) => step.type), [
      MacroStepType.navigate,
      MacroStepType.click,
    ]);
  });
}
