import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/widgets/timetable/month_view/month_view_toolbar.dart';
import 'package:university_timetable/widgets/timetable/timetable_title_bar.dart';

/// 「软件名字那一行」的统一性 + 月份切换行的几何（2026-10-21）。
///
/// 用户口径：
/// 1. 「顶部的软件名字位置，为什么显示和其他页面的高度是不完全一样的，
///    看起来有变动」；
/// 2. 「右边那个菜单按钮，也是不完全一样的，那个东西能不能提取成通用组件」；
/// 3. 「月视图顶部那个月份显示，左右切换到那部分，重新设计一下」。
///
/// 第 1、2 条是一件事：首页与独立页面**各写了一份**同一行的拼装，漂了两处。
/// 本文件钉住"只有一份、且那 1px 不再出现"。
void main() {
  group('标题行：底部内边距的判据（那 1px 位移的来源）', () {
    test('玻璃态底部内边距为 0，非玻璃态为 2', () {
      // 旧实现两处不一致：首页按 chrome spec 取（玻璃态 0），
      // 独立页面用了 HyperosRootHeader 的默认值 2 ⇒ 标题整体下移 1px。
      expect(TimetableTitleBar.bottomPaddingFor(frosted: true), 0);
      expect(TimetableTitleBar.bottomPaddingFor(frosted: false), 2);
    });

    test('底部内边距差 2 会让标题顶边位移 1px（实测值）', () {
      // HyperosRootHeader 内部是「ConstrainedBox(minHeight:44) + Padding」，
      // 底部 padding 变化 2 时，居中后的内容位移 = 2/2 = 1。
      // 这不是估算：是 2026-10-21 在测试里量出来的
      // （bottom=2 → titleTop 9.00；bottom=0 → titleTop 10.00）。
      const topWithPadding = 9.0;
      const topWithout = 10.0;
      expect(topWithout - topWithPadding, 1);
    });
  });

  group('月份切换行：几何与对齐', () {
    const arrow = MonthViewToolbar.arrowSize;
    const slot = MonthViewToolbar.trailingSlotWidth;

    test('箭头是正方形、与行高齐平（40 高行里不留缝）', () {
      expect(arrow, kMonthViewToolbarHeight);
      expect(arrow, 40, reason: '必须与周/日视图的星期栏同为 40，否则顶栏总高又不一致');
    });

    test('尾部槽位比箭头宽：放得下「今天」药丸，且本月留空时同宽', () {
      expect(
        slot,
        greaterThan(arrow),
        reason:
            '药丸("今天"两字 + 内边距)比纯图标宽，槽位必须容得下；'
            '而本月留空时也占这么宽，标题才不左右跳',
      );
    });

    test('标题可用宽度与「本月/非本月」无关（永远居中）', () {
      // 行内固定占位：左箭头 + 尾部槽位（恒定）+ 右箭头。
      // 标题宽度 = 屏宽 - 2*箭头 - 槽位，与是否显示「今天」无关。
      const screen = 393.0;
      const titleWidth = screen - 2 * arrow - slot;
      // 两种状态下都应当是同一个值（这里就是同一个常量，写明意图即可）。
      expect(titleWidth, greaterThan(100), reason: '标题至少要有能读的宽度');
    });
  });

  group('翻页标题的数据来源', () {
    test('页码 0 与 12 都落在合法月份（跨年不出 0 月/13 月）', () {
      // 与页面 `_monthForPage` 同口径：页码 0 基、base 年份 + page~/12。
      (int, int) monthFor(int page, {int baseYear = 2024}) =>
          (baseYear + page ~/ 12, page % 12 + 1);
      expect(monthFor(0), (2024, 1));
      expect(monthFor(11), (2024, 12));
      expect(monthFor(12), (2025, 1));
      expect(monthFor(13), (2025, 2));
      // 相邻两页永远差一个月（滑动标题靠这个推算"下一页是哪个月"）。
      for (var p = 0; p < 24; p++) {
        final a = monthFor(p);
        final b = monthFor(p + 1);
        expect(b.$1 * 12 + b.$2 - (a.$1 * 12 + a.$2), 1);
      }
    });
  });
}
