// 发版前的重点自检：v2.1.4.1 的「本次重点」第三条当时写成了 `转场掉帧`，
// 与任何条目的二字组重合率都不到阈值，解析器认不回 → 退化成 kind=other、
// 无分类标签的灰色重点。这个 CLI 把同一件事变成能挡在 tag 之前的门禁。
//
// 用法：dart run tool/check_release_highlights.dart [notes 路径]
//   不传路径时按 pubspec 的 version 推出 `docs/releases/vX.Y.Z[N].md`。
// 退出码：0 全部认回；1 有认不回的（逐条打印）；2 文件不存在。
import 'dart:io';

import 'package:university_timetable/utils/release_notes_digest.dart';

/// 与 `test/docs/release_notes_format_test.dart` 同一套映射：
/// `A.B.C-N+build` → `vA.B.C.N`，`A.B.C+build` → `vA.B.C`。
String tagForPubspecVersion(String version) {
  final withoutBuild = version.split('+').first;
  final dash = withoutBuild.indexOf('-');
  if (dash < 0) return 'v$withoutBuild';
  final base = withoutBuild.substring(0, dash);
  final fourth = withoutBuild.substring(dash + 1);
  return 'v$base.$fourth';
}

String readPubspecVersion([String path = 'pubspec.yaml']) {
  final line = File(
    path,
  ).readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
  return line.substring('version:'.length).trim();
}

void main(List<String> args) {
  final path = args.isNotEmpty
      ? args.first
      : 'docs/releases/${tagForPubspecVersion(readPubspecVersion())}.md';
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('FAIL 发版说明不存在：$path');
    exit(2);
  }

  final digest = buildReleaseNotesDigest(file.readAsStringSync());
  if (!digest.highlightsDeclared) {
    stdout.writeln(
      '$path 没有 `> 本次重点：…` 行：弹窗会退化成按「新增>优化>移除>修复」猜',
    );
    exit(0);
  }

  final unresolved = digest.unresolvedHighlights;
  if (unresolved.isEmpty) {
    final names = digest.highlights
        .map((h) => '${h.label.isEmpty ? '?' : h.label}·${h.headline}')
        .join('、');
    stdout.writeln(
      '「本次重点」${digest.highlights.length} 条全部认回条目：$names',
    );
    exit(0);
  }

  stderr.writeln('「本次重点」里有认不回条目的说法（会显示成没有分类标签的灰色重点）：');
  for (final item in unresolved) {
    stderr.writeln('       「${item.headline}」');
  }
  stderr.writeln('       改法：把简写换成条目里的原话（含其中几个字即可），'
      '例如条目是「转场更顺：进页面时……」就写「转场更顺」。');
  exit(1);
}
