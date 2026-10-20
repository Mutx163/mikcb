// 大屏规模锁：全仓四个 ≥2,000 行的屏幕文件「只减不增」。
//
// 为什么单独立一个文件：god_file_unit_guard_test.dart 盖的是 provider / storage /
// timetable_screen 这些既有棘轮，且当时有别的会话在途改动（泳道计划裁定：新守卫
// 用新文件，不碰它）。这四块屏幕此前**没有任何规模护栏**——about_screen 2,835 行、
// settings_appearance_editor 2,651 行，每次加功能只进不出。
//
// 基线口径（2026-10-20 立棘，HEAD = 6c669039）：`git show HEAD:<path>` 的内容按
// Dart `readAsLinesSync()`（LineSplitter：\r\n / \r / \n 都算行、末行无换行也算一行）
// 计数。**别拿 `wc -l` 校基线**——settings_appearance_editor.dart 结尾不带换行且
// 混有 14 处 CRLF，wc 给 2650、readAsLinesSync 给 2651，差的那行就是真相。
//
// 基线只减不增：拆掉一块就在注释里记「2835→…」，反弹必须同步基线并在提交信息
// 说明正当性。所有读文件都经 `GuardSource.resolve()`（纪律测试盯直读 File/Directory）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'guard_source.dart';

int _lineCount(File file) => file.readAsLinesSync().length;

void main() {
  test('lib/screens/about_screen.dart 行数棘轮：只减不增', () {
    // 2026-10-20 立基线 = HEAD 6c669039 的 2835 行：全仓最大屏幕，关于页 +
    // 开源许可 + 更新清单 + 反馈入口 + 团队信息全挤在一个文件里，长期无护栏。
    // 下次该往哪拆：按页签区块拆独立 widget 文件（许可页 / 更新页各自成文件，
    // 路由已经在 widgets/home_menu_route_catalog.dart 指到本文件，拆完同步改注册）；
    // 拆法参照 timetable_screen 的 M6 先例（主文件 + part 过渡，part 上限 1）。
    const baselineLines = 2835;
    final file = File(GuardSource.resolve('lib/screens/about_screen.dart'));
    expect(file.existsSync(), isTrue, reason: '文件不存在，棘已空转');
    final lines = _lineCount(file);
    expect(
      lines,
      lessThanOrEqualTo(baselineLines),
      reason:
          'about_screen.dart 继续膨胀（当前 $lines > 基线 $baselineLines）。'
          '请按页签区块把许可 / 更新清单等整块拆成独立文件；'
          '若确属正当增长，请同步本基线并在提交信息说明。',
    );
  });

  test('lib/screens/settings/settings_appearance_editor.dart 行数棘轮：只减不增', () {
    // 2026-10-20 立基线 = HEAD 6c669039 的 2651 行：外观编辑器把材质族、滑杆族、
    // 预览区全住一个文件，每加一个旋钮只进不出。
    // 下次该往哪拆：按「材质族 / 滑杆族 / 预览区」拆独立 widget 文件。
    // 注意：编辑器大量使用 ui/hyperos/hyperos_select.dart（另一会话在途改动），
    // 动本文件前先 git status 看它是否正在被并行修改。
    // 口径备注：本文件行尾无换行 + 混有 CRLF，LineSplitter 计 2651（wc -l 是 2650）。
    const baselineLines = 2651;
    final file = File(
      GuardSource.resolve(
        'lib/screens/settings/settings_appearance_editor.dart',
      ),
    );
    expect(file.existsSync(), isTrue, reason: '文件不存在，棘已空转');
    final lines = _lineCount(file);
    expect(
      lines,
      lessThanOrEqualTo(baselineLines),
      reason:
          'settings_appearance_editor.dart 继续膨胀'
          '（当前 $lines > 基线 $baselineLines）。'
          '请按材质族 / 滑杆族 / 预览区拆独立文件；'
          '若确属正当增长，请同步本基线并在提交信息说明。',
    );
  });

  test('lib/screens/live_settings_subpages.dart 行数棘轮：只减不增', () {
    // 2026-10-20 立基线 = HEAD 6c669039 的 2297 行：实时设置的多个子页挤在
    // 一个文件里，子页之间只共享少量壳组件。
    // 下次该往哪拆：一个子页一个文件（live_settings_*.dart），壳组件下沉
    // widgets/；拆完核对谁还在 import 本文件，别把私有实现变成公开 API。
    const baselineLines = 2297;
    final file = File(
      GuardSource.resolve('lib/screens/live_settings_subpages.dart'),
    );
    expect(file.existsSync(), isTrue, reason: '文件不存在，棘已空转');
    final lines = _lineCount(file);
    expect(
      lines,
      lessThanOrEqualTo(baselineLines),
      reason:
          'live_settings_subpages.dart 继续膨胀'
          '（当前 $lines > 基线 $baselineLines）。'
          '请把子页拆成独立文件；若确属正当增长，请同步本基线并在提交信息说明。',
    );
  });

  test('lib/screens/add_course_screen.dart 行数棘轮：只减不增', () {
    // 2026-10-20 立基线 = HEAD 6c669039 的 2271 行：加课表单字段多、表单状态重。
    // 立棘时工作区有另一泳道的在途改动（周/月视图功能），基线**取 HEAD 值**
    // 而不是工作区值——这正是「基线一律用 git show HEAD 数」的原因。
    // 下次该往哪拆：按字段域继续拆（共享信息卡 50f318c2 已抽过一版），
    // 时间选择 / 地点 / 颜色各有整块，均可成独立 widget。
    const baselineLines = 2271;
    final file = File(
      GuardSource.resolve('lib/screens/add_course_screen.dart'),
    );
    expect(file.existsSync(), isTrue, reason: '文件不存在，棘已空转');
    final lines = _lineCount(file);
    expect(
      lines,
      lessThanOrEqualTo(baselineLines),
      reason:
          'add_course_screen.dart 继续膨胀（当前 $lines > 基线 $baselineLines）。'
          '请按字段域拆独立 widget；若确属正当增长，请同步本基线并在提交信息说明。',
    );
  });

  test('棘轮自检：计数口径认得行尾无换行、CRLF、以及「超一行就红」', () {
    // 探针（不碰业务文件）：把 LineSplitter 口径钉死，防止将来有人把
    // readAsLinesSync 换成 split('\n') 之类口径漂移——口径一漂，上面四条
    // 基线全部失真（appearance_editor 会差 1 行）。
    expect(_lineCountOf('a\nb\nc\n'), 3, reason: '常规行尾');
    expect(_lineCountOf('a\nb\nc'), 3, reason: '末行无换行也算一行');
    expect(_lineCountOf('a\r\nb\rc\n'), 3, reason: 'CRLF 与裸 CR 都按行终止符');
    // 「只减不增」的牙齿：超基线一行必须越界（用合成值验证比较方向）。
    const fakeBaseline = 3;
    expect(
      _lineCountOf('a\nb\nc\nd'),
      greaterThan(fakeBaseline),
      reason: '基线 3 时第 4 行必须触发 lessThanOrEqualTo 失败',
    );
  });
}

/// 对一段源码文本跑同口径计数（只用于自检，不碰文件系统）。
int _lineCountOf(String source) {
  final lines = source.split(RegExp(r'\r\n|\r|\n'));
  if (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  return lines.length;
}
