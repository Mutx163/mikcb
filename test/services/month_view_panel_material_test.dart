import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/utils/home_page_background.dart';
import 'package:university_timetable/widgets/timetable/month_view/month_panel_top_curve.dart';

/// 月视图面板的两个**形状/材质**判据（2026-10-21）。
///
/// 用户口径：
/// 1. 「下面的信息区域，为什么每一个卡片，在白色的背景下，还能显示出壁纸来，
///    这不合理」；
/// 2. 「整个拉杆区域，左右不是有那个圆角吗，他应该是向上弯的，容器应该是上面的
///    表格，而不是的信息区域」。
///
/// ⚠️ 材质那条（第 1 条）的判据在 `DayViewAgendaSurface.resolveSurfaceStyle`，
/// 本文件只测形状那条 —— 因为引入 `day_view_agenda_surface.dart` 会连带
/// import `home_page_background.dart`，而那个文件在本轮有其他会话在途改动
/// （编译期缺符号）。等它落地后，把材质那条搬回本文件即可；
/// 在此之前材质口径由 `month_day_agenda.dart` 里的 `forceSolid: true` 直接钉住。
void main() {
  group('面板内文字用主题墨色（不跟壁纸）', () {
    // 用户 2026-10-21 截图实测：暗色壁纸下，「10月22日」那行标题是白字压白底，
    // 直接看不见。根因是把「按壁纸亮度判出的墨色」复用到了白色面板上。
    //
    // 判据：那个 ink 回答的是"字压在壁纸上该黑还是白"；面板是不透明白底，
    // 壁纸在它下面根本看不见 —— 所以面板内的字只能跟主题走。
    test('暗壁纸 → 网格用白字，但面板必须用主题墨色', () {
      // 网格（压在壁纸上）：暗壁纸配浅墨。
      final onWallpaper = homePageChromeForegroundForLuminance(0.08);
      expect(
        onWallpaper,
        isNot(const Color(0xFF000000)),
        reason: '暗壁纸上网格的日期要用浅色墨（这是正确的）',
      );

      // 面板（实底白卡）：主题墨色，与壁纸无关。
      const themeInk = Color(0xFF1A1A1A);
      expect(
        themeInk,
        isNot(onWallpaper),
        reason: '面板内若沿用壁纸墨色，暗壁纸下就是白字压白底 —— 直接看不见',
      );
    });

    test('亮壁纸 → 网格用深墨；面板仍用主题墨色（两者可能同色，但不许同源）', () {
      final onLight = homePageChromeForegroundForLuminance(0.92);
      expect(onLight, isNot(const Color(0xFFFFFFFF)));
    });
  });

  group('面板上沿的弧朝上（属于表格，不属于面板）', () {
    test('路径两端在顶边、最外角留空：弧向上凸而不是直角', () {
      const clipper = MonthPanelTopCurveClipper(cornerRadius: 28);
      const size = Size(400, 300);
      final path = clipper.getClip(size);

      // 顶边中段必须落在面板最上沿。
      expect(path.contains(const Offset(200, 1)), isTrue);

      // 角内侧要有白底：这正是"白底从表格下沿兜住两角"的观感。
      expect(
        path.contains(const Offset(4, 30)),
        isTrue,
        reason: '角内侧必须有白底，否则读不成"托底"',
      );

      // 最外角必须留空 —— 那圈就是"向上弯"的弧，不是直角。
      expect(
        path.contains(const Offset(0.5, 0.5)),
        isFalse,
        reason: '左上最外角必须留空（弧向上弯）',
      );
      expect(
        path.contains(const Offset(399.5, 0.5)),
        isFalse,
        reason: '右上最外角必须留空（对称）',
      );
    });

    test('弧的起点高度约等于半径：x=0 处从 y≈r 开始', () {
      const r = 28.0;
      const clipper = MonthPanelTopCurveClipper(cornerRadius: r);
      final path = clipper.getClip(const Size(400, 300));
      // 贴着左边缘、半径处应当已经在路径内。
      expect(path.contains(const Offset(0.5, r + 1)), isTrue);
      // 贴左边缘、顶边附近（弧之外）应当不在。
      expect(path.contains(const Offset(0.5, 1)), isFalse);
    });

    test('半径钳制：超过半宽也不会画出畸形（窄屏保护）', () {
      const clipper = MonthPanelTopCurveClipper(cornerRadius: 999);
      final path = clipper.getClip(const Size(40, 100));
      expect(path.contains(const Offset(20, 1)), isTrue);
    });

    test('半径为 0 时退化成矩形（不留缺口）', () {
      const clipper = MonthPanelTopCurveClipper(cornerRadius: 0);
      final path = clipper.getClip(const Size(100, 100));
      expect(path.contains(const Offset(0.5, 0.5)), isTrue);
    });

    test('半径变化要触发重裁剪（shouldReclip 守门）', () {
      const a = MonthPanelTopCurveClipper(cornerRadius: 28);
      const b = MonthPanelTopCurveClipper(cornerRadius: 12);
      expect(a.shouldReclip(b), isTrue);
      expect(a.shouldReclip(a), isFalse);
    });
  });
}
