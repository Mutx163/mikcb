// 模糊出界的「透明黑」守卫：`lib/` 下每一处 `ImageFilter.blur` 都必须显式给
// `tileMode`。
//
// 为什么要有这条：`ImageFilter.blur` 的默认语义（unspecified → **decal**）会把模糊
// 结果在**离图边约 3σ** 的带里淡成**透明黑**。凡是"模糊之后的边是可见的"表面
// （顶栏磨砂带的底边、圆角药丸的轮廓、弹窗面板的边缘…）都会在那条带上读出一条黑边 /
// 黑线，**宽度随模糊量走、模糊调到 0 就消失**——这正是识别它的指纹。
//
// 真机两次实测：
//  * 2026-09-19：弹窗顶边一条黑线、星期栏底边一条黑线（`liquid_glass_surface.dart`
//    的 `compose` 那层模糊没给 tileMode）→ 修法是补 `TileMode.clamp`（磨砂档
//    `stable_frosted_surface.dart` 一直用 clamp，真机不发黑）。
//  * 2026-09-20：打开磨砂强度后星期栏底下横着一条黑线（用户截图）→
//    `hyperos_collapsible_top_app_bar.dart` 的顶栏 BackdropFilter 又漏了同一处。
//
// 这条规则原先只写在笔记里（`2026-09-18-liquid-glass-surface.md`），于是第二天在另一
// 个表面上又踩了一次 —— 所以落成扫描测试：新增模糊时忘了给 tileMode，这里直接红。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 例外用**行内标记**而不是整文件白名单：标记写在调用上方几行内，且必须写明理由。
///
/// 整文件白名单会连带放过同一个文件里**新加**的漏网模糊（`liquid_glass_surface.dart`
/// 就同时有"该给 clamp"和"故意不给"两处），所以精确到调用点。
const _okMarker = 'blur-tile-mode-ok';

/// 标记允许出现在调用上方多少行内。
const _okMarkerLookback = 4;

/// 把 `//` 行注释去掉后再扫。
///
/// 括号配平会被注释里的圆括号带偏（字符串里的 `//` 会误伤，但 `lib/` 下的模糊实参
/// 里不会出现这种东西）。全角括号（备注里常用的）不参与配平，不需要处理。
String _stripLineComments(String source) => source
    .split('\n')
    .map((line) {
      final index = line.indexOf('//');
      return index >= 0 ? line.substring(0, index) : line;
    })
    .join('\n');

/// 取出每处 `ImageFilter.blur(` 的实参文本（按圆括号配平切）。
List<({int line, String args})> _blurCalls(String source) {
  const needle = 'ImageFilter.blur(';
  final calls = <({int line, String args})>[];
  var searchFrom = 0;
  while (true) {
    final index = source.indexOf(needle, searchFrom);
    if (index < 0) break;
    final start = index + needle.length;
    var depth = 1;
    var cursor = start;
    while (cursor < source.length && depth > 0) {
      final char = source[cursor];
      if (char == '(') {
        depth++;
      } else if (char == ')') {
        depth--;
      }
      cursor++;
    }
    calls.add((
      line: '\n'.allMatches(source.substring(0, index)).length + 1,
      args: source.substring(start, cursor - 1),
    ));
    searchFrom = cursor;
  }
  return calls;
}

/// 调用上方 [_okMarkerLookback] 行内有没有豁免标记。
bool _hasOkMarker(List<String> rawLines, int line) {
  final from = (line - _okMarkerLookback).clamp(0, rawLines.length);
  for (var i = from; i < line && i < rawLines.length; i++) {
    if (rawLines[i].contains(_okMarker)) {
      return true;
    }
  }
  return false;
}

void main() {
  test('lib/ 下每处 ImageFilter.blur 都必须显式给出 tileMode', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final path = entity.path.replaceAll(r'\', '/');
      final raw = entity.readAsStringSync();
      final rawLines = raw.split('\n');
      for (final call in _blurCalls(_stripLineComments(raw))) {
        if (call.args.contains('tileMode')) {
          continue;
        }
        if (_hasOkMarker(rawLines, call.line - 1)) {
          continue;
        }
        offenders.add('$path:${call.line}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          '这些模糊没给 tileMode：默认 decal 会让结果在离边约 3σ 的带里淡成透明黑，'
          '模糊之后边可见的地方就会读出一条黑线（宽度随模糊量走、模糊调到 0 消失）。'
          '修法：tileMode: TileMode.clamp。'
          '确实是"淡出看不见"的（例如 σ 小到 3σ < 1 逻辑 px），在调用上方写一行 '
          '`// $_okMarker：<理由>` 豁免。',
    );
  });

  test('守卫本身有效：能扫出漏给 tileMode 的模糊，且认豁免标记', () {
    // 反向自检：解析器必须真的能分辨"给了"与"没给"，否则这条守卫是摆设。
    const sample = '''
      filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      // blur-tile-mode-ok：测试用
      filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      filter: ui.ImageFilter.blur(
        sigmaX: 8,
        sigmaY: 8,
        tileMode: ui.TileMode.clamp,
      ),
    ''';
    final calls = _blurCalls(sample);
    expect(calls, hasLength(3));
    expect(calls[0].args.contains('tileMode'), isFalse);
    // 行号要指得准（红了才知道去哪改）：三引号开头那行换行会被忽略，所以首个调用在第 1 行。
    expect(calls[0].line, 1);
    expect(calls[1].line, 3);
    expect(calls[1].args.contains('tileMode'), isFalse);
    // 第二处上方有豁免标记 ⇒ 不算违规；第三处本来就给了 tileMode。
    final rawLines = sample.split('\n');
    expect(_hasOkMarker(rawLines, calls[1].line - 1), isTrue);
    expect(_hasOkMarker(rawLines, calls[0].line - 1), isFalse);
    expect(calls[2].args.contains('tileMode'), isTrue);
  });
}
