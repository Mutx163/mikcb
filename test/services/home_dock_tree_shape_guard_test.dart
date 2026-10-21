import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 守卫：进出内嵌页**不许改变首页子树的树形**（2026-10-21）。
///
/// ## 用户报的问题及其根因
///
/// 「切出来的时候怎么还是在闪」。日志给了决定性证据：
///
/// ```text
/// [frame-perf] burst frames=2 worstBuildMs=40.4 verdict=ui-bound
/// ```
///
/// 一帧 UI 线程 40ms = **重建整棵子树**，不是"采样图过期"。
///
/// 根因是 dock shell 里这个三元表达式：
///
/// ```dart
/// final hostedContent = inlineBuilder == null
///     ? dockContent                                    // 深度 0
///     : Stack(children: [dockContent, inlinePage]);    // 深度 1
/// ```
///
/// 进出内嵌页时 `dockContent` 在祖先链里的**位置变了**，Flutter 按位置复用元素
/// ⇒ 整棵首页（壁纸 / 课程卡 / 玻璃带 / 右上角那颗球）销毁重建 ⇒ 球闪一下。
///
/// 修法是让 Stack 恒在、内嵌页那层恒在（空时占位）。
///
/// ## 为什么这条守卫要读源码
///
/// 这是**结构**约束：任何 widget 级断言都只能看到"当前这一刻的树"，看不到
/// "两种状态下树形是否一致"。而结构漂移恰恰只在两者之间体现。
/// 读源码里的那段模式是最直接的判据 —— 它一旦被写回来，说明有人又用了
/// "按需包一层"的写法。
void main() {
  test('dock shell 不许用「按需包 Stack」的三元树形', () {
    // 用 package 里的路径定位源码（测试运行目录是仓库根）。
    final file = File('lib/widgets/timetable/timetable_home_dock_shell.dart');
    expect(file.existsSync(), isTrue, reason: '守卫要能读到被守护的文件');

    final source = file.readAsStringSync();
    // 去掉注释行，避免把"说明文字里引用的旧写法"当成真代码命中。
    final code = source
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');

    expect(
      RegExp(r'inlineBuilder\s*==\s*null\s*\?\s*dockContent').hasMatch(code),
      isFalse,
      reason:
          '这段三元式会让首页从"裸内容"变成"Stack 的孩子"，深度变化触发整棵'
          '子树重建 —— 日志里 worstBuildMs=40.4 就是它的代价，表现是切出内嵌页'
          '时右上角那颗球闪一下。必须改成 Stack 恒在、内嵌页那层恒在。',
    );
  });

  test('首页那层的可见性/动画开关必须绑在状态上，不许写死 false', () {
    final source = File(
      'lib/widgets/timetable/timetable_home_dock_shell.dart',
    ).readAsStringSync();
    final code = source
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');

    // Stack 恒在之后，这一层每帧都在树上；写死 false 会让没有内嵌页时
    // 首页也停止绘制（整块消失）。
    expect(
      RegExp(r'visible:\s*false\s*,').hasMatch(code),
      isFalse,
      reason: '恒在的首页层不能把 visible 写死 false —— 没有内嵌页时首页会消失',
    );
    expect(
      code.contains('visible: !covered'),
      isTrue,
      reason: '可见性必须跟随 covered',
    );
  });
}
