import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 发版说明的格式护栏：**只盯当前 pubspec 对应的那一份**。
///
/// ## 为什么盯「末尾有没有换行」
///
/// `.github/workflows/android-build.yml` 的「Read app version」这一步把 release notes
/// 用 heredoc 写进 `$GITHUB_OUTPUT`：
///
/// ```bash
/// echo "release_notes<<EOF" >> "$GITHUB_OUTPUT"
/// cat "${RELEASE_NOTES_FILE}" >> "$GITHUB_OUTPUT"
/// echo "EOF" >> "$GITHUB_OUTPUT"
/// ```
///
/// **那个 `echo "EOF"` 只是往文件末尾追加字符串，它自己不带换行。** 所以 notes 文件
/// 一旦没有结尾换行，最后一行就会和 `EOF` 粘成 `……是安全的。EOF`，runner 扫不到
/// 「单独一行 EOF」，整步报：
///
/// ```
/// Invalid value. Matching delimiter not found 'EOF'
/// Unable to process file command 'output' successfully.
/// ```
///
/// 这个坑非常安静：分析、测试、其它门禁全绿，**只有打 tag 那一刻才炸**；而且
/// `release_body`（grep 出来的那些 `- ` 行）因为末条恰好带换行而侥幸没事，只有
/// `release_notes`（整份文件 `cat`）中招，于是报错指向一个跟内容毫无关系的地方。
/// 2026-10-06 发 v2.1.3.3 就是这么炸的；v2.1.3.2 的文件恰好有换行所以没事。
/// 换句话说：**这是一个「上次侥幸没踩」的坑**，不钉住就还会再来一次。
///
/// ## 为什么只查当前版本，不普查全部文件
///
/// `docs/releases/` 里有 121 份历史说明，其中 4 份没有结尾换行、4 份含 CRLF ——
/// 全是早已发布的历史版本。已发布的说明是**只读**的（改它们等于篡改历史发布记录），
/// 而且那些 CRLF 文件当年确实构建成功了，说明 CRLF 并不致命（git 检出时多半已被
/// 规范化）。真正致命的只有「末尾缺换行」，且只影响**正在发的那一份**。
/// 普查会把一批不该动的历史文件变成红灯，逼人去改它们 —— 那比这个坑本身更糟。

/// 从 pubspec 的 `version:` 推出对外 tag（与 mikcb-release skill 的映射一致）：
/// `A.B.C-N+build` → `vA.B.C.N`，`A.B.C+build` → `vA.B.C`。
String tagForPubspecVersion(String version) {
  final withoutBuild = version.split('+').first;
  final dash = withoutBuild.indexOf('-');
  if (dash < 0) return 'v$withoutBuild';
  final base = withoutBuild.substring(0, dash);
  final fourth = withoutBuild.substring(dash + 1);
  return 'v$base.$fourth';
}

String readPubspecVersion() {
  final line = File(
    'pubspec.yaml',
  ).readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
  return line.substring('version:'.length).trim();
}

void main() {
  test('pubspec 的版本能推出 tag 名（否则下面整套断言都在测别的东西）', () {
    expect(tagForPubspecVersion('2.1.3-3+138'), 'v2.1.3.3');
    expect(tagForPubspecVersion('2.1.3+138'), 'v2.1.3');
    expect(tagForPubspecVersion('1.3.2-0+109'), 'v1.3.2.0');
  });

  test('当前版本的发版说明存在、以换行结尾、无 BOM、无 CRLF', () {
    final tag = tagForPubspecVersion(readPubspecVersion());
    final file = File('docs/releases/$tag.md');

    expect(
      file.existsSync(),
      isTrue,
      reason: '$tag 的发版说明不存在：${file.path}。'
          '工作流在打包时会去读它，缺文件会退化成一句占位文案。',
    );

    final bytes = file.readAsBytesSync();
    expect(bytes, isNotEmpty, reason: '${file.path} 是空文件');
    expect(
      bytes.last,
      0x0a,
      reason: '${file.path} 末尾没有换行。工作流用 heredoc 把它写进 \$GITHUB_OUTPUT，'
          '缺换行会让最后一行与 EOF 粘在一起 —— 分析测试全绿，只有打 tag 时才炸。',
    );

    final hasBom =
        bytes.length >= 3 &&
        bytes[0] == 0xef &&
        bytes[1] == 0xbb &&
        bytes[2] == 0xbf;
    expect(hasBom, isFalse, reason: '${file.path} 带 UTF-8 BOM');

    final hasCrlf = RegExp('\r\n').hasMatch(String.fromCharCodes(bytes));
    expect(hasCrlf, isFalse, reason: '${file.path} 含 CRLF');
  });
}