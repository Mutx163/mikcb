package com.mutx163.qingyu.pages.settings

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.calculateEndPadding
import androidx.compose.foundation.layout.calculateStartPadding
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.rememberSheetMaxHeight
import kotlinx.coroutines.launch
import top.yukonga.miuix.kmp.basic.TabRowWithContour

/** 材质面板页序：0 = 通用，1 = 课程卡片（`settings_appearance_editor.dart:2253-2255`）。 */
object MaterialSheetPages {
    const val GENERAL = 0

    /** 与课程卡片设置页「卡片外观」跳转牌共用一个下标（`SettingsMaterialSheetPage`，:85-88）。 */
    const val COURSE_CARD = SettingsMaterialSheetPage.COURSE_CARD_PAGE_INDEX

    /** 页数 = 页签表长度：标签与页一一对应（:2332 的两个标签 = :2348-2349 的两页）。 */
    val COUNT: Int get() = SettingsMaterialSheetPage.TAB_LABELS.size
}

/**
 * Dart `_materialSheetMaxHeightFactor`（`settings_appearance_editor.dart:120`）：
 * 面板**整体**最多占屏幕一半。超出的内容由每一页自己的滚动承担。
 */
private const val MATERIAL_SHEET_MAX_HEIGHT_FACTOR = 0.5f

/**
 * 官方弹层载体头的高度：把手条 24（`DragHandleArea`）+ 空标题行 18。
 *
 * 载体（`OverlayBottomSheet` / `WindowBottomSheet` 共用的 `BottomSheetContentLayout`）把这两段
 * 排在**内容之外**，所以正文上限要扣掉它们，面板整体才等于 Dart 的「最多半屏」（:120、:162-166）。
 * 宿主必须传 `title = null`——页签行自己就是标题（:2312-2314）。
 */
private val MATERIAL_SHEET_CARRIER_CHROME = 42.dp

/**
 * 材质弹层的正文：顶上「通用 / 课程卡片」翻页页签（**自己就是标题**），下面一层可左右滑
 * 的两页 —— 与 [WallpaperSheetBody] **同一个形状**。
 *
 * ## 为什么翻页必须内联在这一层
 *
 * 弹层面板是**根覆盖层自插条目**：任何二级弹层（路由、锚定气泡、再一层覆盖层条目）都会被它压在
 * 背面，点不到（`settings_appearance_editor.dart:864-867`，2026-09-19 真机实锤）。所以两页不是两次
 * 导航，而是同一层里的横向 pager。
 *
 * ## 两页内容从哪来
 *
 * 面板**不重排内容**，只消费设置族模型：
 * - 第一页 [SettingsMaterialGeneralPage.spec]（`_buildGeneralMaterialPage`，:930-1195）；
 * - 第二页 [SettingsMaterialCourseCardPage.spec]（`_buildCourseCardMaterialPage`，:1215-1317）。
 *
 * 于是「哪一行在什么档位下出现」只有一处判据。三条最容易写反的规矩都落在模型里、本文件不再重复判断：
 * 1. **「高级材质」整块只在当前生效档是液态玻璃时出现**（:1019 / :1267）：`SettingsMaterialModel
 *    .glassModeChoice` 由 `frostedBlurEnabled` 推出，实体档下档位滑杆、八根旋钮、深色档、坞开关
 *    整块不渲染（实体档只多一段说明，:985-993）。
 * 2. **「独立设置深色档」字段存的是「是否跟随」**，显示值取反（:1106-1109）：模型里
 *    `switchValue = !material.linkLiquidGlassTuning`。
 * 3. **卡片磨砂滑杆上限是 24 不是 40**（`kPreblurMaxSigma`，:1299-1302）：模型用
 *    `LiquidGlassTuning.PREBLUR_MAX_SIGMA`，超出部分在出图侧会被夹掉，滑杆不跟着收口就是两头死区。
 *
 * ## 骨架逐条对照
 *
 * | Dart（`settings_appearance_editor.dart`） | 本实现 |
 * |---|---|
 * | :2253-2255 页序常量 | [MaterialSheetPages] |
 * | :2260-2267 `initialPage` 只在 initState 收一次，非课程卡片回通用 | `rememberPagerState(initialPage = 归一化值)` |
 * | :2257 / :2269-2273 `PageController` 跨重建存活、离场释放 | `rememberPagerState`（随本 composable 的生命周期） |
 * | :2275-2287 点页签切页，选中态立刻跟手 | 页签点击 `scope.launch { animateScrollToPage }`；选中态读 `pagerState.currentPage` |
 * | :2296 `HyperosSheetBlurTop`（把手 24 + 胶囊 40 + 渐隐 20） | 页签行占独立一行、**不叠加**在滚动内容上；正文不垫那 84（否则凭空多一块空档） |
 * | :2293 草稿版本号一变整块重画 | 本函数是 [AppearanceEditorState] 的纯函数：宿主换 `state` 即重组 |
 * | :2325-2337 页签行 = 把手让位 + 居中胶囊 + `generalSettingsTitle` / `surfaceCourseCard` | [TabRowWithContour] + `SettingsMaterialSheetPage.TAB_LABELS`（官方轮廓轨道，0/∞ 铺满整行） |
 * | :2338-2351 `PageView` + `onPageChanged` 回收索引 | [HorizontalPager]（`currentPage` 由 pager 自己维护，滑页后页签跟着亮） |
 * | :2338-2339 面板总高由外层 `maxHeight`（半屏）顶住 | [MATERIAL_SHEET_MAX_HEIGHT_FACTOR] + 载体头 [MATERIAL_SHEET_CARRIER_CHROME] |
 * | :955-960 / :1230-1235 每页自带顶部让位与底部留白 | 顶部为 0（见上）；底部 = 手势区 + 16（键盘弹出时只留 16，见 [SheetContentBottomGap]） |
 * | :947-960 / :1226-1235 每页一层独立竖向滚动 | 每页 [SettingsNodeList]（内部 `QingyuPageList`：官方三件套 + 滚动条） |
 * | :2348-2349 两页 child 顺序 | [materialPageNodes] 按下标分派 |
 *
 * ## 行部件为什么复用
 *
 * 两页的内容与设置列表同源（同一批 [SettingsNode]），面板里再写一套「长得像」的控件就是两套方言：
 * 字号、圆角、按压反馈迟早各走各的。所以这里只负责「页签 + 翻页 + 高度 + 留白」，行部件走
 * [SettingsNodeList]（内部即 [SettingsNodeView]）——开关 / 单选 / 滑杆都是官方 preference 系列本体。
 *
 * ## 数据源与写回
 *
 * 面板**只消费** [AppearanceEditorState.material]，不读设置模型、不复制第二份真源：
 * * 读：`AppearanceEditorBridge.toState` 从 `TimetableSettingsModel` 逐键搬（每条映射的 Dart 行号写在桥里）；
 * * 写：每行把 `(action, target, rowId)` 原样转出给宿主，宿主交 `SettingsActionDispatcher`。
 *   这里的 rowId 就是分派器的常量（`material.general.*` / `material.courseCard.*`），改名要两边一起改。
 *
 * 唯一一个「不是直接读键」的值是 `hasHomePageBackdrop`：它来自壁纸状态，课卡的表面地图靠它回落
 * 实体（`surface_material.dart:96-107`），与 Dart 同口径。
 *
 * ## 与 Dart 的已知差异（都不在本文件的写作用域，交给对应泳道决定）
 *
 * | # | 差异 | Dart | 现状 / 归属 |
 * |---|---|---|---|
 * | 1 | 顶部**渐变模糊带**未接线：页签占独立一行、内容不从带底下滚过 | :2296-2337 | 全仓 `miuix-blur` 真实页面 0 处接线（见 AGENTS「不在本守卫范围」那节），属后续批次 |
 * | 2 | 「恢复默认」原件是**整宽次按钮**，模型给的是分组内 ARROW 行 + 独立范围说明 | :1053-1085 | `SettingsMaterialPanels.kt`（点得动、语义对，形态不同） |
 * | 3 | 区块间距：Dart 用 16 / 20，模型统一 12 | :994 / :1020 / :1044 / :1088 / :1140 / :1161 | `SettingsGap` 默认值 = 全站 `sectionGap` 12；属全局口径，不是漏项 |
 * | 4 | 点页签切页：Dart 立即点亮 + 260ms `easeOutCubic`；这里用 pager 自带的滚动动画（选中态读 `currentPage`） | :2275-2287 | 官方 pager 动画，不自研（禁止自写转场/动画） |
 * | 5 | 顶部翻页控件在 Dart 是**筛选胶囊**（`HyperosChipRow`，:2331-2335），刻意与面板内的分段长得不一样，好让用户分清「换一类看」和「改一个值」（:2315-2320）；官方 miuix 没有 chip row 对应物 | :2315-2337 | Lead 2026-10-29 拍板：与面板内分段统一用官方 `TabRowWithContour`（0/∞ 铺满），这条视觉区分暂缺 |
 *
 * 两处**曾挡路、已由 Lead 在共享层补齐**（记在这里，免得后人再实现一遍）：
 * * 三个多选项行（默认材质 / 首页顶栏玻璃 / 卡片外观）：渲染层 `MiuixRowComponent.RADIO` 现在按
 *   `options.size` 分流——多条走 `SegmentedRow`（官方 `TabRowWithContour`，就是 Dart `_MaterialSegmented`
 *   的同一个物）；模型这边保持「一条 `SettingsRow` 带多个 `options`」即可，不用拆行。
 * * 滑杆建议点位：`SettingsSliderSpec` 增加 `showKeyPoints` / `keyPoints`，`SliderRow` 已透传给官方
 *   `SliderPreference`；本泳道已在 `SettingsMaterialPanels.kt` 按 Dart :1441-1444（档位 10 格）与
 *   :1492-1495 / :1506-1509 / :1521-1524 / :1571-1574（卡片四根旋钮）填好。
 *
 * @param state 本页状态（材质那份真源在 [MaterialPanelState]）。
 * @param onAction 行动作原样转出（渲染层不碰业务判据），宿主接分派器。
 * @param contentPadding 调用方的**额外**留白（默认 0）。面板底部那截「手势区 + 16」由本函数自己带
 *   （Dart `scrollableBottomGap` + `bottomGapInsetOf`），调用方不要再垫一份，否则翻倍。
 * @param initialPage 打开时停在第几页；[MaterialSheetPages.COURSE_CARD] 是「课程卡片」设置页里那块
 *   「卡片外观」跳进来时的落点（:85-88）。与 Dart 同口径：**不是课程卡片就回通用**，只在首次组合
 *   时生效（之后翻页由用户操作接管）。
 */
@Composable
fun MaterialSheetBody(
    state: AppearanceEditorState,
    onAction: (action: SettingsAction, target: String?, rowId: String) -> Unit,
    modifier: Modifier = Modifier,
    contentPadding: PaddingValues = PaddingValues(),
    initialPage: Int = MaterialSheetPages.GENERAL,
) {
    val pageCount = MaterialSheetPages.COUNT
    // Dart :2263-2264：`initialPage == 课程卡片 ? 课程卡片 : 通用`。没有「夹到最后一页」这种归桶
    // ——大于页数的值在 Dart 里也回通用，所以这里同样只认那一个值。
    val startPage = if (initialPage == MaterialSheetPages.COURSE_CARD) {
        MaterialSheetPages.COURSE_CARD
    } else {
        MaterialSheetPages.GENERAL
    }
    // Dart :2257 / :2266：控制器建一次、跨重建存活。Compose 的 `remember` 就是这条语义；
    // 宿主收起弹层时内容离场，状态随之释放，下次打开重新从 `initialPage` 起算（:2260-2267 同）。
    val pagerState = rememberPagerState(
        initialPage = startPage,
        pageCount = { pageCount },
    )
    val scope = rememberCoroutineScope()

    // Dart :120 / :162-166：面板整体最多半屏（顶部那圈 chrome 现在是 0）。载体把把手条与空标题行
    // 排在内容之外，正文上限要扣掉这两段，面板整体才等于「屏高 × 0.5」；否则面板会比原版高 42。
    val maxHeight = (rememberSheetMaxHeight(MATERIAL_SHEET_MAX_HEIGHT_FACTOR) -
        MATERIAL_SHEET_CARRIER_CHROME).coerceAtLeast(0.dp)

    // Dart `bottomGapInsetOf`（`miuix_bottom_sheet.dart:459-461`）= 系统手势区 + 16。官方弹层只按
    // 键盘让位（`imePadding`）、不管导航栏，所以这一截必须由**滚动内容自己**带：垫在视口外面的话，
    // 内容永远滚不进那一块，面板底下会留一块空玻璃（:890-894 的同一条说明）。
    //
    // 键盘弹出时面板已经被官方弹层抬到键盘上方，面板底边与键盘之间没有手势区；仍按
    // 「手势区 + 16」垫就会多出一截空白。判据走共享纯函数，与 `QingyuSheet` 同一口径。
    val density = LocalDensity.current
    val navBottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    val bottomGap = SheetContentBottomGap.bottomGapDp(
        imeVisible = SheetContentBottomGap.isImeVisible(WindowInsets.ime.getBottom(density)),
        navigationBarBottomDp = navBottom.value,
    ).dp

    val layoutDirection = LocalLayoutDirection.current
    val pagePadding = PaddingValues(
        start = contentPadding.calculateStartPadding(layoutDirection),
        top = contentPadding.calculateTopPadding(),
        end = contentPadding.calculateEndPadding(layoutDirection),
        bottom = contentPadding.calculateBottomPadding() + bottomGap,
    )

    Column(
        modifier = modifier
            .fillMaxWidth()
            // 上限而不是定高（与 Dart 的 `maxHeight` 同一语义）。里面的 pager 带 `weight`，
            // 所以面板会占满这半屏、两页等高——与 Dart 的 `PageView` 一样总是撑满上限，
            // 溢出的内容交给每页自己的滚动。
            .heightIn(max = maxHeight),
    ) {
        TabRowWithContour(
            tabs = SettingsMaterialSheetPage.TAB_LABELS.map { it.text },
            // 选中态跟 pager 的真实页走：用户自己滑出来的那一页也由 `currentPage` 回收索引
            // （Dart :2342-2346 的 `onPageChanged` 是同一件事），不会出现「滑过去一格、页签还亮着
            // 原来那格」。
            selectedTabIndex = pagerState.currentPage,
            onTabSelected = { index ->
                scope.launch { pagerState.animateScrollToPage(index) }
            },
            // 官方 `TabRowWithContour` 默认按 62~84 定宽从左排，格数少时右边空一大块；
            // 放宽到 0 / ∞ 让它铺满整行（与渲染层 `SegmentedRow` 同一口径，Lead 2026-10-29 拍板）。
            minWidth = 0.dp,
            maxWidth = Dp.Infinity,
            // 官方 demo 的页签行内距（`component/TabRowSection.kt:37-47` 的 `padding(horizontal)`）；
            // 页面容器的左右 16 来自弹层 `insideMargin`，这里只给页签自己那圈呼吸。
            // ⚠️ 必须用 start/top/end/bottom 那个重载：Compose 没有「horizontal + bottom」组合。
            //
            // 2026-11-05：**左右那 16 去掉**。弹层的 `insideMargin`（`QingyuSheetDefaults.InsideMargin`）
            // 已经给了 Dart 那个 16，再垫一层页签就距边 32、比下面的卡片各窄 16（并排看像一条
            // 悬在中间的窄轨）。发布版胶囊与正文同宽：`settings_appearance_editor.dart:2161-2179`
            // 的 `bleed` 只有那 16。壁纸面板同一处口径（`WallpaperSheetBody`）。
            modifier = Modifier.padding(bottom = 8.dp),
        )
        HorizontalPager(
            state = pagerState,
            modifier = Modifier.weight(1f),
        ) { index ->
            SettingsNodeList(
                nodes = materialPageNodes(state, index),
                onAction = onAction,
                // 每页一层独立竖向滚动：两页等高、各滚各的（Dart :947 / :1226 的两个
                // `SingleChildScrollView`），互不串位置。
                contentPadding = pagePadding,
                // 面板里的行左缘：官方弹层的 `insideMargin` 已经给了 Dart 那个 16，
                // 分组白卡再垫 12 就比 Dart 多 12（行部件内部那 16 是另一回事）。
                rowInset = 0.dp,
            )
        }
    }
}

/**
 * 一页的节点树。
 *
 * `spec` 收的是设置页状态（卡片外观档的真源在那边），面板这里只把已有的那份
 * [MaterialPanelState.courseCardSurfaceStyle] 递进去，不复制第二份真源。
 */
internal fun materialPageNodes(state: AppearanceEditorState, index: Int): List<SettingsNode> {
    val pageState = SettingsPageState(
        courseCardSurfaceStyle = state.material.courseCardSurfaceStyle,
    )
    return when (index) {
        MaterialSheetPages.COURSE_CARD ->
            SettingsMaterialCourseCardPage.spec(pageState, state.material).nodes
        else ->
            SettingsMaterialGeneralPage.spec(pageState, state.material).nodes
    }
}