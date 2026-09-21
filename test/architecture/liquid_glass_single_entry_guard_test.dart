// 「液态玻璃只有一个参数出口」守卫：`lib/` 下除声明外，`LiquidGlassStyle` 只允许在
// `lib/models/liquid_glass_tuning.dart` 里被构造。
//
// 为什么要有这条：历史上出现过「同一个材质两种观感」——一条自带抓拍纹理的折射通道，
// 只有部分表面走它，于是顶栏一种观感、弹窗另一种（那条通道与它依赖的第三方包已整体删除，
// 见 `.agents/notes/implemented/architecture/2026-09-18-liquid-glass-surface.md`）。
// `LiquidGlassTuning.toStyle` 是压住这件事的唯一入口，也是浅/深成对配方
// （`.agents/notes/proposed/architecture/2026-09-21-liquid-glass-light-dark-pair.md`）
// 的唯一落点：一旦某个表面自己 `LiquidGlassStyle(...)` 一个出来，成对逻辑就被绕过了，
// 而且绕过之后不会有任何测试报错 —— 所以用扫描测试钉住。
//
// 行为侧的姊妹守卫在 `test/ui/hyperos/liquid_glass_consistency_test.dart`（圆角只改几何）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 允许出现的文件 → 该文件里允许的出现形式。
const _constructionSite = 'lib/models/liquid_glass_tuning.dart';
const _declarationSite = 'lib/ui/hyperos/liquid/liquid_glass_shader.dart';

/// 扫出的每一处 `LiquidGlassStyle(` 及其所在行。
List<({String path, int line, String text})> _hits(String root) {
  const needle = 'LiquidGlassStyle(';
  final hits = <({String path, int line, String text})>[];
  for (final entity in Directory(root).listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }
    final path = entity.path.replaceAll(r'\', '/');
    final lines = entity.readAsStringSync().split('\n');
    for (var i = 0; i < lines.length; i++) {
      // 行注释里的提及不算（本文件与文档里就大量引用这个名字）。
      final code = lines[i].split('//').first;
      if (code.contains(needle)) {
        hits.add((path: path, line: i + 1, text: code.trim()));
      }
    }
  }
  return hits;
}

void main() {
  test('lib/ 下只有 LiquidGlassTuning 能构造 LiquidGlassStyle', () {
    final offenders = <String>[];
    for (final hit in _hits('lib')) {
      if (hit.path == _constructionSite) {
        continue;
      }
      if (hit.path == _declarationSite &&
          hit.text.startsWith('const LiquidGlassStyle(')) {
        continue;
      }
      offenders.add('${hit.path}:${hit.line}');
    }

    expect(
      offenders,
      isEmpty,
      reason:
          '这些地方自己构造了 LiquidGlassStyle，绕过了 LiquidGlassTuning.toStyle —— '
          '浅/深成对配方与「全 app 一套观感」都会在那里失效，且不会有别的测试报错。'
          '修法：改成调 toStyle()（它已经是唯一出口），或把需要的旋钮加到 LiquidGlassTuning 上。',
    );
  });

  test('守卫本身有效：能认出构造点，也认声明与注释里的提及', () {
    // 反向自检：扫描器必须真的能分辨"构造"与"声明"，否则这条守卫是摆设。
    const declaration = 'class LiquidGlassStyle {\n'
        '  const LiquidGlassStyle({\n'
        '    required this.tint,\n'
        '  });\n'
        '}\n';
    expect(_hitsOf(declaration), hasLength(1));
    expect(
      _hitsOf(declaration).single.text.startsWith('const LiquidGlassStyle('),
      isTrue,
      reason: '声明行必须被识别成声明，否则上面那条守卫会把它算成违规',
    );

    const construction = 'return LiquidGlassStyle(\n  tint: tint,\n);\n';
    final hit = _hitsOf(construction).single;
    expect(hit.text.startsWith('return LiquidGlassStyle('), isTrue);
    expect(
      hit.text.startsWith('const LiquidGlassStyle('),
      isFalse,
      reason: '构造点不该被当成声明放行',
    );

    // 注释里的提及不算。
    expect(_hitsOf('// 见 LiquidGlassStyle( 的说明\n'), isEmpty);
    // 行号要指得准（红了才知道去哪改）。
    expect(_hitsOf('a\nb\nLiquidGlassStyle(\n').single.line, 3);
  });
}

/// 对一段源码文本跑同一套扫描（只用于自检，不碰文件系统）。
List<({String path, int line, String text})> _hitsOf(String source) {
  const needle = 'LiquidGlassStyle(';
  final hits = <({String path, int line, String text})>[];
  final lines = source.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final code = lines[i].split('//').first;
    if (code.contains(needle)) {
      hits.add((path: '<sample>', line: i + 1, text: code.trim()));
    }
  }
  return hits;
}
