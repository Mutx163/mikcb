import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 上帝单元（一个类/文件承担多个模块职责）的「总量」棘轮（2026-10-19 立）。
///
/// 旧棘轮只量主文件行数，于是「把代码搬进同库 part」就能让门禁变绿：
/// - `timetable_screen`：2026-10-10 拆分前 10,948 行；今天主文件 8,156 +
///   两个 part 2,829 = 10,985 行，总量没有下降。
/// - `timetable_provider`：主文件 4,534 + 10 个 part 3,479 = 8,013 行；
///   part 里仍有 573 处直接访问 `host._私有字段` —— 这是同一个类的 11 个抽屉，
///   不是 11 个模块。
///
/// 本守卫按「逻辑单元」计量（主文件 + 同族 part），并给 part 数量、provider
/// part 对宿主私有字段的访问数设上限。三者都只减不增。
///
/// 正当增长的处理顺序：先把这个功能域抽成独立 widget/service（真边界，不是新
/// part），做不到就先停下来讨论；不要抬基线换绿。
///
/// 与既有守卫的分工：
/// - `timetable_screen_size_guard_test.dart`：课表页主文件行数；
/// - `dependency_guards_test.dart`：provider 主文件行数、storage 行数等；
/// - 本文件：逻辑单元总量 + part 数量 + provider 分片的宿主私有访问数。
void main() {
  test('timetable_screen 逻辑单元总行数棘轮：只减不增', () {
    const baselineLines = 10985;
    const unit = [
      'lib/screens/timetable_screen.dart',
      'lib/screens/timetable_day_view_part.dart',
      'lib/screens/timetable_update_download_part.dart',
    ];
    final lines = unit.fold<int>(0, (sum, path) => sum + _lineCount(path));
    expect(
      lines,
      lessThanOrEqualTo(baselineLines),
      reason:
          'timetable_screen 逻辑单元继续膨胀（当前 $lines > 基线 $baselineLines）。'
          '新功能请放进独立 widget/controller；不要靠新增 part 摊薄主文件。',
    );

    final partCount = Directory('lib/screens')
        .listSync()
        .whereType<File>()
        .where(
          (f) => RegExp(
            r'timetable_.*_part\.dart$',
          ).hasMatch(f.path.replaceAll('\\', '/')),
        )
        .length;
    expect(
      partCount,
      lessThanOrEqualTo(2),
      reason:
          '课表页 part 数量涨到 $partCount（基线 2）。part 只作零行为搬迁的过渡，'
          '新拆分请直接产出独立 widget/controller。',
    );
  });

  test('timetable_provider 逻辑单元总行数棘轮：只减不增', () {
    const baselineLines = 8013;
    final parts = _providerParts();
    final lines =
        _lineCount('lib/providers/timetable_provider.dart') +
        parts.fold<int>(0, (sum, path) => sum + _lineCount(path));
    expect(
      parts.length,
      lessThanOrEqualTo(10),
      reason:
          'provider part 数量涨到 ${parts.length}（基线 10）。'
          '新功能请抽成独立 service，不要继续往 part 里摊。',
    );
    expect(
      lines,
      lessThanOrEqualTo(baselineLines),
      reason:
          'timetable_provider 逻辑单元继续膨胀（当前 $lines > 基线 $baselineLines）。'
          '先抽独立 service/仓储，再同步基线；不要靠新增 part 换绿。',
    );
  });

  test('provider 分片对宿主私有字段的访问棘轮：只减不增', () {
    const baselineHits = 573;
    final hostPrivateAccess = RegExp(r'host\._');
    var hits = 0;
    for (final path in _providerParts()) {
      hits += hostPrivateAccess.allMatches(File(path).readAsStringSync()).length;
    }
    expect(
      hits,
      lessThanOrEqualTo(baselineHits),
      reason:
          'provider part 对 `host._私有字段` 的访问涨到 $hits（基线 $baselineHits）。'
          '这个数不降，说明分片仍和宿主是同一个类；应把该功能域搬进带显式端口的 '
          'service，而不是继续加 part。',
    );
  });

  test('timetable_settings 逻辑单元行数棘轮：只减不增', () {
    const baselineMain = 2621;
    const baselineUnit = 3661;
    const unit = [
      'lib/models/timetable_settings.dart',
      'lib/models/settings/timetable_settings_enums.dart',
      'lib/models/settings/timetable_settings_extensions.dart',
      'lib/models/settings/timetable_settings_live.dart',
    ];
    final mainLines = _lineCount(unit.first);
    final unitLines = unit.fold<int>(0, (sum, path) => sum + _lineCount(path));
    expect(
      mainLines,
      lessThanOrEqualTo(baselineMain),
      reason:
          'timetable_settings.dart 继续膨胀（当前 $mainLines > 基线 $baselineMain）。'
          '新增设置项请拆到按功能域命名的文件；不要往主文件回堆。',
    );
    expect(
      unitLines,
      lessThanOrEqualTo(baselineUnit),
      reason:
          'settings 逻辑单元继续膨胀（当前 $unitLines > 基线 $baselineUnit）。'
          '2026-10-19 拆成主文件 + 3 个 settings/ 文件后总量 3,661（拆分前 3,639，'
          '+22 为文件头与 import）；此后只减不增。',
    );
  });

  test('warehouse 适配器登录页行数棘轮：只减不增', () {
    const baselineLines = 3621;
    final lines = _lineCount(
      'lib/screens/import/warehouse/warehouse_adapter_web_login_screen.dart',
    );
    expect(
      lines,
      lessThanOrEqualTo(baselineLines),
      reason:
          'warehouse 适配器登录页继续膨胀（当前 $lines > 基线 $baselineLines）。'
          '该页应把导入/登录/宏回放编排抽成 controller，WebView 生命周期留在 State。',
    );
  });

  test('全仓 part 指令总数棘轮：只减不增', () {
    const baselineParts = 28;
    final partDirective = RegExp(r"^part\s+'", multiLine: true);
    var total = 0;
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) {
        continue;
      }
      total += partDirective.allMatches(file.readAsStringSync()).length;
    }
    expect(
      total,
      lessThanOrEqualTo(baselineParts),
      reason:
          '全仓 part 指令涨到 $total（基线 $baselineParts）。'
          'part 是把同一个类摊到更多文件，不是模块边界；新拆分请产出独立类。',
    );
  });
}

int _lineCount(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path 不存在，棘已空转');
  return file.readAsLinesSync().length;
}

List<String> _providerParts() {
  final dir = Directory('lib/providers/timetable');
  expect(dir.existsSync(), isTrue, reason: 'provider part 目录不存在，棘已空转');
  final parts =
      dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .map((f) => f.path.replaceAll('\\', '/'))
          .toList()
        ..sort();
  expect(parts, isNotEmpty, reason: 'provider part 列表为空，棘已空转');
  return parts;
}
