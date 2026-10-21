import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'guard_source.dart';

/// 架构守卫：日视图的**摘要卡必须吸顶，且 12px 呼吸是它自己的下内边距**
/// （2026-10-21 立）。
///
/// ## 为什么需要这道守卫
///
/// 改前是 `Column：摘要卡 / SizedBox(12) / Expanded(列表)` —— 两块彼此独立，
/// 摘要卡永远不动，列表只是它下面那块框里的滚动体，而**框的顶边比摘要卡下沿
/// 还低 12px**。于是卡片往上滚时被「框顶」硬切、永远够不到摘要卡底下，中间
/// 那条 12px 缝就一直是空的。
///
/// 用户口径原话：「如果把下面卡片滑动上去，为什么不是下面卡片直接插到顶部
/// 卡片下面，而是看到了有一定的空隙」。修法是把两者合成一条
/// `CustomScrollView`：摘要卡做 `PinnedHeaderSliver`、12px 变成吸顶头自己的
/// 下内边距，于是静止时间距不变、一滑就钻到卡片底下。
///
/// ## 这道守卫钉的是什么
///
/// 钉的是**结构**，不是像素。像素那一半（静止缝 = 12、滚动后摘要卡下沿不动、
/// 有卡顶边越过下沿）验在
/// `.agents/notes/implemented/feature/2026-10-21-day-view-pinned-summary-header.md`
/// 的「验证」一节 —— 那一轮用临时探针跑过并做过咬合探针，但结论**没有**留成
/// 仓库测试：按 TEST-POLICY，`test/widgets` 是冻结目录不许新增，而
/// `integration_test/` 要真机才能跑。所以结构这一半由本守卫长期看住。
///
/// ⚠️ 这条豁免的代价要认：**像素那一半现在没有回归网**。将来若要补，位置是
/// `integration_test/`（真机跑一次日视图滚动）。
/// 从 `marker` 之后开始，取到括号配平为止的那一段源码（粗粒度足够用于守卫）。
String _blockAfter(String source, String marker) {
  final start = source.indexOf(marker);
  if (start < 0) {
    return '';
  }
  var depth = 0;
  var seenOpen = false;
  for (var i = start; i < source.length; i++) {
    final ch = source[i];
    if (ch == '(') {
      depth++;
      seenOpen = true;
    } else if (ch == ')') {
      depth--;
      if (seenOpen && depth == 0) {
        return source.substring(start, i + 1);
      }
    }
  }
  return source.substring(start);
}

void main() {
  test('日视图：摘要卡必须吸顶，且 12px 是它的下内边距而不是死空白', () {
    // 结构壳单独成文件（`god_file_unit_guard` 要求新功能别塞进已卡棘轮的
    // part）。这里同时查两处：壳里放吸顶头，part 里只放内容。
    const shellPath =
        'lib/widgets/timetable/day_view/day_view_scroll_shell.dart';
    const partPath = 'lib/screens/timetable_day_view_part.dart';

    final shell = File(GuardSource.resolve(shellPath));
    final part = File(GuardSource.resolve(partPath));
    expect(shell.existsSync(), isTrue, reason: '$shellPath 不存在，守卫已空转');
    expect(part.existsSync(), isTrue, reason: '$partPath 不存在，守卫已空转');
    final shellSource = shell.readAsStringSync();
    final partSource = part.readAsStringSync();

    // 1. 吸顶头必须在，且必须在 CustomScrollView 的 slivers 里。
    expect(
      shellSource.contains('PinnedHeaderSliver'),
      isTrue,
      reason:
          '摘要卡必须用 PinnedHeaderSliver 吸顶。改回「Column + 固定高度的摘要卡 + '
          'Expanded(列表)」的话，列表顶边会再次低于摘要卡下沿，卡片就滑不到它'
          '底下（用户 2026-10-21 报的那条空隙）。',
    );
    final scrollViewAt = shellSource.indexOf('CustomScrollView(');
    final pinnedAt = shellSource.indexOf('PinnedHeaderSliver');
    expect(scrollViewAt > 0, isTrue, reason: '没找到 CustomScrollView，守卫已失效');
    expect(
      pinnedAt > scrollViewAt,
      isTrue,
      reason: 'PinnedHeaderSliver 必须写在 CustomScrollView 里（在其之后）',
    );

    // 2. 那 12px 呼吸必须是吸顶头**自己的下内边距**，不能是两块之间的固定空白。
    //
    // 判据要盯"它出现在哪个位置"，而不是"文件里有没有这个词"：
    // 第一版只查 `contains('headerBreathing')`，把它改回
    // `SliverToBoxAdapter(SizedBox(height: headerBreathing))` 时**照样绿** ——
    // 那个词还在，只是换了个更糟的用法（死空白）。咬合探针就是这么做出来的。
    final pinnedBlock = _blockAfter(shellSource, 'PinnedHeaderSliver(');
    expect(
      pinnedBlock.contains('headerBreathing'),
      isTrue,
      reason:
          '摘要卡的 12px 呼吸必须是**吸顶头自己的下内边距**（`PinnedHeaderSliver` 的 '
          'child 里的 Padding 用 `headerBreathing`）。写在两块之间（比如吸顶头之后'
          '再插一个 SliverToBoxAdapter(SizedBox)）的话，它是一块**不参与滚动**的'
          '死空白，卡片撞上就被硬切 —— 正是用户报的那条空隙。',
    );

    // 3. part 里不能再出现「摘要卡 + SizedBox(12) + Expanded(列表)」的老函数。
    //
    // 只认**定义与调用**（`Widget _buildExpandedDayColumnView(` / 调用点），
    // 不认注释里的提及 —— 改名说明里写着「由 `_buildExpandedDayColumnView`
    // 改来」，那是账不是代码。第一版守卫没区分，被自己的注释顶红了。
    final legacyDef = RegExp(
      r'_buildExpandedDayColumnView\s*\(',
    ).hasMatch(partSource.replaceAll(RegExp(r'^\s*///.*$', multiLine: true), ''));
    expect(
      legacyDef,
      isFalse,
      reason:
          '老函数 `_buildExpandedDayColumnView`（自带滚动体的那版）不该回来。'
          '它返回 Widget 而不是 sliver，一旦出现就说明又回到了两块独立。',
    );
  });
}
