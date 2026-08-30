import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 架构守卫棘轮（OPTIMIZATION.md 阶段 0 收尾：度量进 CI）。
///
/// 守卫值只许下降不许上涨；确需放宽时，把基线改成新值并在提交信息说明
/// 理由。下降后欢迎顺手收紧基线。
void main() {
  final providerPath = 'lib/providers/timetable_provider.dart';
  final providerFile = File(providerPath);

  List<File> libDartFiles() {
    return Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.replaceAll('\\', '/').endsWith('.dart'))
        .toList();
  }

  test('timetable_provider.dart 行数棘轮：只减不增', () {
    // 4401→4409: applyCourseRecolors 整对象替换改为按字段 copyWith（+9，
    // 防过期快照回写非颜色字段），拆分归阶段 3 重构，按测试约定同步基线。
    const baselineLines = 4409;
    final lines = providerFile.readAsLinesSync().length;
    expect(
      lines,
      lessThanOrEqualTo(baselineLines),
      reason: '向上帝类继续堆积被禁止（解耦方案阶段 3 将拆分本类）。'
          '若确有正当增长，请同步调高本基线并在提交信息说明。',
    );
  });

  test('timetable_provider 的 lib 扇入棘轮：只减不增', () {
    const baselineFanIn = 48;
    final importers = libDartFiles()
        .where(
          (file) =>
              !file.path.replaceAll('\\', '/').endsWith(providerPath) &&
              file.readAsStringSync().contains(
                "import '../providers/timetable_provider.dart'",
              ),
        )
        .length;
    expect(
      importers,
      lessThanOrEqualTo(baselineFanIn),
      reason: '新文件不应再直接依赖 TimetableProvider；'
          '确需依赖时同步调高本基线并说明理由。',
    );
  });

  test('_persistActiveProfileState 调用点棘轮：写放大只减不增', () {
    const baselineCallSites = 48;
    final partFiles = [
      providerFile,
      File('lib/providers/timetable/import_export_service.dart'),
      File('lib/providers/timetable/time_scheme_repository.dart'),
      File('lib/providers/timetable/live_activity_controller.dart'),
    ];
    const marker = '_persistActiveProfileState(';
    var callSites = 0;
    for (final file in partFiles) {
      callSites += marker.allMatches(file.readAsStringSync()).length;
    }
    expect(
      callSites,
      lessThanOrEqualTo(baselineCallSites),
      reason: '全量覆写调用点是阶段 2 要消灭的写放大指标，不应新增。',
    );
  });

  test('lib/domain 保持无 UI 框架依赖（纯领域层）', () {
    final forbidden = RegExp(
      r'''import\s+['"]package:flutter/(widgets|material|cupertino)\.dart['"]''',
    );
    final violations = <String>[];
    for (final file in Directory('lib/domain').listSync().whereType<File>()) {
      if (!file.path.endsWith('.dart')) {
        continue;
      }
      if (forbidden.hasMatch(file.readAsStringSync())) {
        violations.add(file.path.replaceAll('\\', '/'));
      }
    }
    expect(
      violations,
      isEmpty,
      reason: '领域层只允许纯 Dart 与 models 依赖（flutter/foundation 例外）；'
          '发现 UI 依赖请上移到 UI 层或改依赖注入。',
    );
  });
}
