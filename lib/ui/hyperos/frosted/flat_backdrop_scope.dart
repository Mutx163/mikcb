import 'package:flutter/widgets.dart';

/// 「玻璃背后是**一张平色底**，采不到任何东西」这个全局事实。
///
/// ## 为什么需要它
///
/// 玻璃面板的可见形状**几乎全部来自它背后的内容**：染色是半透明白色，边缘折射把
/// 背后的东西拉进来，模糊把背后的色块揉开。于是「面板内嵌套的卡片」也跟着用
/// **白色水洗**（见 `HyperosBlurredHeader.nestedLiquidTileTintColor`：浅色白 28%）
/// 来和面板分层 —— 白色压在**有颜色**的玻璃上是一块更亮的方块，分层读得出来。
///
/// 背后是平色底时这条链整个塌掉（**浅色、无壁纸**的算术）：
///
/// ```text
/// 页面底色            #F8FAFC   ← timetablePageBackgroundColor 默认值，近白
/// 面板 = 白 0.70 压上去 #FDFDFD
/// 卡片 = 白 0.28 压上去 #FEFEFE   ← 与面板差 1～2 个色阶
/// ```
///
/// 白叠白 = 没画。课程弹窗里的「时间 / 老师 / 地点 / 备注 / 添加任务 / 闹钟」
/// 几行于是全部融进面板，只剩文字（用户口径 2026-09-29：「这弹窗上的框框什么的，
/// 都是和弹窗颜色一样，看不出来框框」）。
///
/// 同一件事在别处已经修过一次：`frosted_header_background.dart` 里
/// `sheetPanelFellBackSolid` —— 面板被**技术 / 系统门禁**（平台视图、无障碍降级）
/// 摘成纯白实体时，嵌套 tile 改走**中性水洗**（浅色黑 5%）。但那条闸门只认技术
/// 条件，**不认「背后没东西可采」** —— 没壁纸时着色器后端是好的、玻璃照画，只是
/// 采到一片近白，出图与实底几乎一样，却还挂在「玻璃」那条路上继续刷白。
///
/// 这个作用域把「没东西可采」补成同一条判据，让两种「面板读作不透明浅色卡片」的
/// 情形收敛到同一个中性水洗。
///
/// ## 为什么挂在 MaterialApp 之上
///
/// 弹窗家族走根 Overlay（`MiuixGlassTransformPopup` / `MiuixWindowBottomSheet`），
/// 注入面的 context **不在**宿主页面子树里 —— 在页面上挂 scope，弹窗里的 tile 读
/// 不到。口径与 `FrostedAppearanceScope` / `LiquidGlassDegradationScope` 相同：
/// 都挂在 `MaterialApp.builder` 里，位于 Navigator 与 Overlay 之上。
///
/// ## 取值口径
///
/// 判据是 `!hasHomePageBackdrop(settings)`（`utils/home_page_background.dart` 的
/// 单一真源，与课程卡 `effectiveCourseCardSurfaceStyle` 同源）：没设壁纸时**全 app
/// 的页面都是平色底**，此时任何玻璃面板背后都没有可采样的内容。
///
/// 已知边界：**设了壁纸、但壁纸被作用范围限制在别的区域**（`homePageBackgroundScope`
/// 不含 `timetable`）时，本作用域报 false，而弹窗背后仍是平色 —— 那属于另一个
/// 「按宿主逐块判定」的问题，判据得由开弹窗的页面给，成本远大于收益，本次不覆盖。
class HyperosFlatBackdropScope extends InheritedWidget {
  const HyperosFlatBackdropScope({
    required this.isFlat,
    required super.child,
    super.key,
  });

  /// 背后是不是一张平色底（= 没设可用的壁纸）。
  ///
  /// 默认（作用域缺席，测试与独立组件）按**有壁纸**处理：缺席时读成 flat 会让
  /// 每一条不挂作用域的既有测试与预览集体改色，代价与收益不成比例。
  final bool isFlat;

  static HyperosFlatBackdropScope? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<HyperosFlatBackdropScope>();

  /// 背后是平色底吗。作用域缺席 = false（当作背后有东西可采）。
  static bool isFlatOf(BuildContext context) =>
      maybeOf(context)?.isFlat ?? false;

  @override
  bool updateShouldNotify(covariant HyperosFlatBackdropScope oldWidget) =>
      isFlat != oldWidget.isFlat;
}
