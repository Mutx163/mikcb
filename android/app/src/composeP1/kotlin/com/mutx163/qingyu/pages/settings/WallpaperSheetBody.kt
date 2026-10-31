package com.mutx163.qingyu.pages.settings

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import android.widget.Toast
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuPageList
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import top.yukonga.miuix.kmp.basic.TabRowWithContour

/** 壁纸面板页序：0 = 壁纸，1 = 设置（`settings_appearance_editor.dart:2115-2117`）。 */
object WallpaperSheetPages {
    const val PICKER = 0
    const val SETTINGS = 1
    const val COUNT = 2
}

/**
 * 壁纸面板往外发动作时用的 target 串（宿主 / 分派器按这些串认）。
 *
 * 前四条**逐字复用模型里已有的串**，不另造一套：
 * [ROW_PICK] / [ROW_MISSING] / [ROW_ADJUST] / [ROW_CLEAR] 就是
 * `SettingsBackdropFlowPage.imageRows`（`:188-240`）里的 `row.id` 与 `actionTarget`，
 * [recentConfirmDelete] 与那里 `backdrop.recent.confirmDelete:$armed`（`:137`）逐字一致。
 *
 * 后三条是「点完之后要发生什么」——Dart 里由 mixin 自己执行（`:325-378`、`:294-316`），
 * Kotlin 侧数据边界在分派器，所以只剩**意图**要传出去：
 *
 * | target | 数据侧应当做什么 | Dart |
 * |---|---|---|
 * | `backdrop.image.picked:<uri>` | 把选中的图收进受管壁纸目录，写 `homePageWallpaperPath` + 居中（align 0/0、scale 1），并补记一条「最近使用」 | `:1007-1019` / `:1070-1091` |
 * | `backdrop.recent.select:<key>` | 切回该条（连取景一起还原）并补记一条历史 | `:294-316` |
 * | `backdrop.recent.confirmDelete:<key>` | 摘条目 + 落盘 + **排进** `RECENT_WALLPAPER_UNDO_WINDOW_MS` 之后的删文件队列 | `:325-354` |
 * | `backdrop.recent.undoRemove:<key>` | 整份历史原样放回，并把该文件从待删队列里摘掉 | `:356-378` |
 */
object WallpaperSheetTargets {

    /** 「选择图片」行（模型 `backdrop.image.pick`，Dart `:903-909`）。 */
    const val ROW_PICK = "backdrop.image.pick"

    /** 「图片文件已丢失」警示行：点它同样回到选图（模型 `backdrop.image.missing`，Dart `:892-895`）。 */
    const val ROW_MISSING = "backdrop.image.missing"

    /** 「调整位置」行（模型 `backdrop.image.adjust`，Dart `:919-925`）。 */
    const val ROW_ADJUST = "backdrop.image.adjust"

    /** 「清除图片」行（模型 `backdrop.image.clear`，Dart `:927-933`）。 */
    const val ROW_CLEAR = "backdrop.image.clear"

    /** 「最近使用」整段的 rowId（条上的点击 / 移除都挂它）。 */
    const val ROW_RECENT = "backdrop.recent"

    /** 选完图之后带回来的那张（`content://` URI，数据侧负责收进受管目录）。 */
    const val PICKED_PREFIX = "backdrop.image.picked:"

    /** 切回「最近使用」里的某一条。 */
    const val RECENT_SELECT_PREFIX = "backdrop.recent.select:"

    /** 确认删除某一条（与模型 `backdrop.recent.confirmDelete:<key>` 逐字一致）。 */
    const val RECENT_CONFIRM_DELETE_PREFIX = "backdrop.recent.confirmDelete:"

    /** 撤销最近一次删除。 */
    const val RECENT_UNDO_PREFIX = "backdrop.recent.undoRemove:"

    fun picked(uri: String): String = PICKED_PREFIX + uri

    fun recentSelect(key: String): String = RECENT_SELECT_PREFIX + key

    fun recentConfirmDelete(key: String): String = RECENT_CONFIRM_DELETE_PREFIX + key

    fun recentUndo(key: String): String = RECENT_UNDO_PREFIX + key
}

/**
 * 「每天自动更换」那颗开关的取值来源认不认得出来。
 *
 * 认不出来时**不许画成能点的开关**：Dart 那颗开关的真源是 `BingWallpaperStore`
 * 台账，它不走草稿、也不走宿主 `setState`（`settings_home_backdrop_flow.dart:501-526`，
 * 2026-10-06 实报「点了一下没反应」）。Kotlin 侧台账接线还没到位，
 * [BackdropFlowState.bingAutoApplyEnabled] 现在只能是出厂值 false —— 再画成可点的开关，
 * 就是「点了没反应」那个坑原样复刻。所以默认 [UNKNOWN]：行照渲染、但禁用并把
 * 说明换成 ARB 已有的「不可用」（`SettingsStrings.aboutUnavailable`），
 * 等数据侧把台账接上，宿主显式传 [LEDGER] 才恢复可点。
 */
enum class WallpaperAutoApplySource {
    /** 真源已接（`BingWallpaperStore` 的台账），开关可点。 */
    LEDGER,

    /** 认不出来 / 还没接：只读禁用，并写明「不可用」。 */
    UNKNOWN,
}

/**
 * 壁纸弹层的正文：顶上「壁纸 / 设置」翻页胶囊（**自己就是标题**），下面一层可左右滑
 * 的两页。形状与 [MaterialSheetBody] **逐字同构**（`settings_appearance_editor.dart:2104-2224`，
 * 用户口径 2026-09-28：「这个弹窗可以参考材质那边的，做切换」）。
 *
 * * **第一页「壁纸」**（`:439-476`）：选图行 + 「最近使用」缩略图条 + 图库入口；
 * * **第二页「设置」**（`:722-737`）：背景随周次滑动开关 + 壁纸模糊滑杆。
 *
 * ## 三条必须守住的（都是真机踩过的坑）
 *
 * 1. **正文里不许出现任何二级弹层 / 路由**：面板是根覆盖层自插条目，二级弹层 / 路由会
 *    落在它**背面**点不到（`:115-149`，2026-09-20 真机口径「页面在弹窗背后，什么都点
 *    不到」）。所以移除确认条与删除后的反悔条都**就地长在同一层列表下面**
 *    （[RecentWallpaperConfirmBar] / `RecentWallpaperUndoBar`），位置编辑页与图库页
 *    一律交给宿主在世界里推（这里只发 [SettingsAction.NAVIGATE]）。
 * 2. **模糊 0 档显示「关闭」而不是 0**，档位夹在 0..24：这两件事由模型
 *    `SettingsBackdropFlowPage.blurRow`（`:278-303`）与 `WallpaperPanelState.MIN_BLUR/MAX_BLUR`
 *    保证，渲染层直接用官方 `SliderPreference` 的读数槽，**不在这里另算一遍**。
 * 3. **移除历史条目要能反悔，且正在用的那张不给移除**：
 *    后者由模型 `SettingsRecentWallpaperSection.cardState/longPressIntent` 判死
 *    （`settings_recent_wallpaper.dart:128-137`、`:271-273`），前者是
 *    [RECENT_WALLPAPER_UNDO_WINDOW_MS]（Dart 2.5s）。
 *
 * ## 两页的节点树同源
 *
 * 两页都来自同一份流程模型（[SettingsBackdropFlowPage] / [SettingsRecentWallpaperSection]）
 * —— Dart 侧这两个 builder 是 `HomeBackdropFlow` mixin，同一套代码服务两个宿主
 * （「课表页面」设置里的壁纸行、以及本页底部那颗「调整壁纸」），这里沿用同一结构，
 * 不许为面板另抄一份。
 *
 * ## 宿主接线要注意的三处几何
 *
 * * 面板的左右内缩取 **0**（模型 `HOST_SHEET_ROW_INSET` → [WallpaperPageList] 的
 *   `rowInset`）：留白全交给官方弹层。宿主推弹层时要显式传
 *   `insideMargin = DpSize(16.dp, 0.dp)` —— miuix 0.9.4 的默认是 `DpSize(24, 0)`，
 *   而 Dart `hyperosMiuixBottomSheetInsideMargin` 是 16（`miuix_bottom_sheet.dart:466-472`）。
 * * 面板行**不带额外卡片底色**：分组在面板里由官方 `QingyuCard` 承载但左右内缩为 0
 *   （`HOST_SHEET_ROWS_HAVE_CARD_BACKGROUND` 的另一半语义），再垫 12 会让行左缘比
 *   Dart 多 12。
 * * **底部留白由滚动内容自己带**（Dart `scrollableBottomGap` +
 *   `bottomGapInsetOf`，`miuix_bottom_sheet.dart:448-458`）：宿主把
 *   [wallpaperSheetBottomGap] 传给 [contentPadding]，**不要**再额外垫 24——
 *   垫在外层，滚动视口够不到屏幕底，面板底下会多出一块永远空的玻璃板。
 *
 * @param state 本页状态（壁纸那份真源在 [WallpaperPanelState]）。
 * @param onAction 行动作原样转出（渲染层不碰业务判据），宿主接分派器。
 * @param selection 宿主算好的那几件「不在设置里」的事。这里**只取
 *   [SelectionPageState.fileMissing]**（Dart `:873-881` 由 `homePageImageProvider` 判，
 *   渲染层不摸盘）；[SelectionPageState.armedKey] 由面板自己持有 —— 移除确认是缩略图条
 *   的界面态，只有画条的这一层能改。传 null = 没有失效路径。
 * @param autoApplySource 「每天自动更换」的真源认不认得出，见 [WallpaperAutoApplySource]。
 * @param contentPadding 滚动内容的额外留白：底部给 [wallpaperSheetBottomGap]，
 *   默认 0（**不要**在这里垫 24，理由见上）。
 * @param initialPage 打开时停在第几页。
 */
@Composable
fun WallpaperSheetBody(
    state: AppearanceEditorState,
    onAction: (action: SettingsAction, target: String?, rowId: String) -> Unit,
    selection: SelectionPageState? = null,
    autoApplySource: WallpaperAutoApplySource = WallpaperAutoApplySource.UNKNOWN,
    modifier: Modifier = Modifier,
    contentPadding: PaddingValues = PaddingValues(0.dp),
    initialPage: Int = WallpaperSheetPages.PICKER,
) {
    val pagerState = rememberPagerState(
        initialPage = initialPage.coerceIn(0, WallpaperSheetPages.COUNT - 1),
        pageCount = { WallpaperSheetPages.COUNT },
    )
    val scope = rememberCoroutineScope()
    val context = LocalContext.current

    // 系统图片选择器：`ActivityResultContracts.PickVisualMedia`（Android 13 起是系统
    // 相册，更老的系统自动退回 `ACTION_OPEN_DOCUMENT`）。与 Dart `:1025-1029` 的
    // `pickAndStoreManagedImage` 同一条：选完 → 定位 → 确认；这里只负责「选」，
    // 收进受管目录与落盘由数据侧按 [WallpaperSheetTargets.PICKED_PREFIX] 做。
    val picker = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickVisualMedia(),
    ) { uri ->
        // 用户取消 → 什么都不做（Dart `:1008-1011` 的 `targetPath == null` 分支）。
        if (uri != null) {
            onAction(
                SettingsAction.WRITE_SETTING,
                WallpaperSheetTargets.picked(uri.toString()),
                WallpaperSheetTargets.ROW_PICK,
            )
        }
    }

    // 「最近使用」的三样纯界面态（都不是设置字段，不活到下次打开）：
    // 已发起移除、刚删掉可撤销、以及一句临时说明。
    var armedKey by rememberSaveable { mutableStateOf<String?>(null) }
    var undoKey by rememberSaveable { mutableStateOf<String?>(null) }
    var notice by rememberSaveable { mutableStateOf<String?>(null) }

    val backdrop = backdropFlowState(state)
    val entries = SettingsBackdropFlowPage.recentEntries(backdrop.history, backdrop.imagePath)
    // 条目被外部改掉（删完 / 换机恢复）之后，不能让一个已经不存在的 key 继续挂着 ——
    // 那会留下一条永远按不掉的确认条（Dart `:80-88`）。
    val armed = SettingsRecentWallpaperSection.normalizeArmedKey(armedKey, entries)

    // 反悔窗：窗口一到就把「可撤销」收掉（Dart `:166-170` 的 2500ms；文件真删由
    // 数据侧读同一个常量去排期）。
    LaunchedEffect(undoKey) {
        val pending = undoKey ?: return@LaunchedEffect
        delay(RECENT_WALLPAPER_UNDO_WINDOW_MS)
        if (undoKey == pending) undoKey = null
    }
    // 「正在使用这张壁纸」那条说明同样是过一会自己收（Dart 用的是 toast）。
    LaunchedEffect(notice) {
        val pending = notice ?: return@LaunchedEffect
        delay(RECENT_WALLPAPER_UNDO_WINDOW_MS)
        if (notice == pending) notice = null
    }

    val recentPanel = RecentWallpaperPanel(
        armedKey = armed,
        undoKey = undoKey,
        notice = notice,
        // 切回某一条：连取景一起还原由数据侧做（Dart `:294-316`）。
        onSelect = { key ->
            onAction(
                SettingsAction.WRITE_SETTING,
                WallpaperSheetTargets.recentSelect(key),
                WallpaperSheetTargets.ROW_RECENT,
            )
        },
        // 角标 / 长按 → 就地进确认态：**不弹任何覆盖层**（`settings_recent_wallpaper.dart:148-154`）。
        onRequestRemove = { key -> armedKey = key },
        // 正在用的那张被长按：只解释一句（Dart `:841-855`），什么都不改。
        onBlockedRemove = {
            notice = SettingsRecentWallpaperSection.REMOVE_IN_USE_TOAST.zh
        },
        onCancelRemove = { armedKey = null },
        // 确认删除：先把确认态收掉、把反悔窗点亮，再把「删哪一条」转给数据侧
        // （摘条目 / 落盘 / 排删文件在 Dart `:318-354`，Kotlin 在分派器）。
        onConfirmRemove = { key ->
            armedKey = null
            undoKey = key
            onAction(
                SettingsAction.WRITE_SETTING,
                WallpaperSheetTargets.recentConfirmDelete(key),
                WallpaperSheetTargets.ROW_RECENT,
            )
        },
        // 撤销：整份历史原样放回由数据侧做（Dart `:356-378`）。
        onUndoRemove = { key ->
            undoKey = null
            onAction(
                SettingsAction.WRITE_SETTING,
                WallpaperSheetTargets.recentUndo(key),
                WallpaperSheetTargets.ROW_RECENT,
            )
        },
    )

    /**
     * 行 → 动作的中转，三种去向：
     * 1. 选图那两条**由面板自己开系统相册**（Dart 里这两条也是流程自己的闭包
     *    `onPick`，`:456` / `:894`）。为什么不能纯转出去：相册选择器必须挂在
     *    ActivityResult 注册表上，那是**这一层**的资格，不是分派器（纯 Kotlin）的。
     * 2. 「调整位置」在本仓**没有目标页**，由面板自己诚实提示（见分支内注释）。
     * 3. 其余一律原样转给宿主。
     */
    val handleAction: (SettingsAction, String?, String) -> Unit =
        { action, target, rowId ->
            val wantsPicker = rowId == WallpaperSheetTargets.ROW_PICK ||
                target == WallpaperSheetTargets.ROW_PICK ||
                target == WallpaperSheetTargets.ROW_MISSING
            val wantsAdjust = rowId == WallpaperSheetTargets.ROW_ADJUST ||
                target == WallpaperSheetTargets.ROW_ADJUST
            when {
                wantsPicker -> picker.launch(
                    PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly),
                )
                // 2026-10-31 F23：这条 `NAVIGATE` 的 target 是 `backdrop.image.adjust`，
                // 分派器不认、路由表也没有键 ⇒ 转出去就是**静默无反应**（点了完全没动静）。
                // 根因是 Dart 的「拖动取景」页还没移植（`BingGalleryApply.kt:325`、
                // `BingGalleryHost.kt:78` 记的是同一处缺口），不是少写一个键。
                // 取景页落地前，这里给一句诚实的「不可用」；落地后把本分支删掉，
                // 让它照常走 `onAction` 即可。
                wantsAdjust -> Toast.makeText(
                    context,
                    SettingsStrings.aboutUnavailable.zh,
                    Toast.LENGTH_SHORT,
                ).show()
                else -> onAction(action, target, rowId)
            }
        }

    // 面板自己拼的那份：`fileMissing` 取宿主算好的那份（Dart `:873-881`），
    // `armedKey` 用面板持有的界面态（宿主传进来的那一份按类注释约定忽略）。
    val pageSelection = SelectionPageState(
        backdrop = backdrop,
        fileMissing = selection?.fileMissing == true,
        armedKey = armed,
    )

    Column(modifier = modifier.fillMaxSize()) {
        TabRowWithContour(
            tabs = SettingsWallpaperSheetPage.TAB_LABELS.map { it.zh },
            selectedTabIndex = pagerState.currentPage,
            // 点胶囊翻页：手势滑动与点选走**同一个** pagerState，不会各走各的
            // （Dart `:2133-2147` 的 `_goToPage` 就是为这件事写的）。
            onTabSelected = { index -> scope.launch { pagerState.animateScrollToPage(index) } },
            // 两格铺满整行：官方默认 minWidth 会让每格只有自身文字宽、行尾留一截空轨。
            minWidth = 0.dp,
            maxWidth = Dp.Infinity,
            modifier = Modifier.padding(start = 16.dp, end = 16.dp, bottom = 8.dp),
        )
        HorizontalPager(
            state = pagerState,
            modifier = Modifier.weight(1f),
        ) { index ->
            WallpaperPageList(
                nodes = wallpaperPageNodes(state, pageSelection, index, autoApplySource),
                onAction = handleAction,
                contentPadding = contentPadding,
                // 只有第一页有「最近使用」那一段（`:2189-2204`）。
                recent = if (index == WallpaperSheetPages.PICKER) recentPanel else null,
            )
        }
    }
}

/** 模型里「最近使用」那一段的节点 id（`SettingsBackdropFlowPage.selectionPage` 的 inline）。 */
private const val RECENT_STRIP_ID = "backdrop.recent"

/** 模型里移除确认条的三处节点 id（`backdrop.recent.confirm*`）。 */
private const val RECENT_CONFIRM_HINT_ID = "backdrop.recent.confirmHint"
private const val RECENT_CONFIRM_ACTIONS_ID = "backdrop.recent.confirmActions"
private const val RECENT_CONFIRM_DELETE_ROW_ID = "backdrop.recent.confirmDelete"
private const val RECENT_CONFIRM_CANCEL_ROW_ID = "backdrop.recent.cancelDelete"

/** 「每天自动更换」那一行的 id（`SettingsBackdropFlowPage` 的 `backdrop.bing.autoApply`）。 */
private const val BING_AUTO_APPLY_ROW_ID = "backdrop.bing.autoApply"

/**
 * 一页的节点树。
 *
 * ⚠️ 面板宿主的内缩与「课表页面」那个宿主不同：面板的左右内缩取 0
 * （`SettingsBackdropFlowPage.HOST_SHEET_ROW_INSET`，理由见该文件 :79-103——面板的
 * `insideMargin` 已经给了 Dart 那个 16，再垫一层就是 32）。
 */
internal fun wallpaperPageNodes(
    state: AppearanceEditorState,
    selection: SelectionPageState,
    index: Int,
    autoApplySource: WallpaperAutoApplySource = WallpaperAutoApplySource.UNKNOWN,
): List<SettingsNode> {
    val backdrop = backdropFlowState(state)
    return when (index) {
        WallpaperSheetPages.SETTINGS -> SettingsBackdropFlowPage.settingsPage(backdrop).nodes
        else -> applyAutoApplySource(
            SettingsBackdropFlowPage.selectionPage(backdrop, selection).nodes,
            autoApplySource,
        )
    }
}

/**
 * 「每天自动更换」的真源认不出来时，把那一行改成**禁用 + 写明「不可用」**。
 *
 * 只动这一行，其余节点原样（包括图库入口那条导航——图库页本身是存在的，
 * `SettingsBingWallpaperGalleryPage`）。
 */
private fun applyAutoApplySource(
    nodes: List<SettingsNode>,
    source: WallpaperAutoApplySource,
): List<SettingsNode> {
    if (source != WallpaperAutoApplySource.UNKNOWN) return nodes
    return nodes.map { node ->
        if (node !is SettingsGroup) {
            node
        } else {
            SettingsGroup(
                id = node.id,
                children = node.children.map { child ->
                    if (child is SettingsRow && child.id == BING_AUTO_APPLY_ROW_ID) {
                        child.copy(
                            enabled = false,
                            // 用 ARB 已有的「不可用」，不新造一句（`SettingsStrings.kt:57-62`
                            // 就是这么定下来的规矩）。
                            subtitleKey = SettingsStrings.aboutUnavailable.key,
                            subtitle = SettingsStrings.aboutUnavailable.zh,
                        )
                    } else {
                        child
                    }
                },
            )
        }
    }
}

/**
 * 一页的列表渲染。
 *
 * 与 [SettingsNodeList] 的两处差异（都只为「最近使用」那一段）：
 *
 * 1. 那段在模型里是 `SettingsInline(CONTROL_CARD)`——官方没有横向缩略图条控件
 *    （`SettingsBackdropFlowPage` 里那条 `note` 写明了），所以按 id 换成真条
 *    [RecentWallpaperBlock]；
 * 2. 确认态的两颗按钮按 Dart 版式改成**并排满宽按钮**（`:178-202`），而不是两条行：
 *    模型把它写成两行是为了「有哪些动作」可断言，版式仍应由渲染层按 Dart 定。
 *
 * 其余节点一律走 [SettingsNodeView]（分组也交给它，白卡的内缩由 [rowInset] 控），
 * 不另写第二套行部件。
 *
 * @param rowInset 分组白卡的左右内缩：**面板里传 0**。官方弹层的 `insideMargin`
 *   已经是 Dart 那个 16，白卡再垫 12 会让行左缘比 Dart 多 12（2026-10-29 Lead 冻结）。
 */
@Composable
internal fun WallpaperPageList(
    nodes: List<SettingsNode>,
    onAction: (action: SettingsAction, target: String?, rowId: String) -> Unit,
    contentPadding: PaddingValues,
    recent: RecentWallpaperPanel? = null,
    modifier: Modifier = Modifier,
    rowInset: Dp = SettingsBackdropFlowPage.HOST_SHEET_ROW_INSET.dp,
) {
    QingyuPageList(
        innerPadding = PaddingValues(0.dp),
        modifier = modifier,
        contentPadding = contentPadding,
    ) {
        items(items = nodes, key = { it.id }) { node ->
            when {
                // 「最近使用」整段：标题 / 说明 / 缩略图条 / 反悔条（`settings_recent_wallpaper.dart:100-205`）。
                node is SettingsInline && node.id == RECENT_STRIP_ID && recent != null ->
                    RecentWallpaperBlock(
                        title = node.label.orEmpty(),
                        subtitle = node.value.orEmpty(),
                        label = node.texts.firstOrNull()?.text
                            ?: SettingsStringsExt1.homePageWallpaperRecentImageLabel.zh,
                        entries = node.colors,
                        selectedKey = node.selectedColor,
                        panel = recent,
                    )

                // 确认态那句警示说明（Dart `:169-176` 用的是 error 色）。
                node is SettingsDescription && node.id == RECENT_CONFIRM_HINT_ID ->
                    RecentWallpaperConfirmHint(text = node.text)

                // 确认态的两颗按钮（`:178-202`）：删除 / 取消等宽并排。
                node is SettingsGroup && node.id == RECENT_CONFIRM_ACTIONS_ID && recent != null -> {
                    val rows = node.children.filterIsInstance<SettingsRow>()
                    val deleteRow = rows.firstOrNull { it.id == RECENT_CONFIRM_DELETE_ROW_ID }
                    val cancelRow = rows.firstOrNull { it.id == RECENT_CONFIRM_CANCEL_ROW_ID }
                    RecentWallpaperConfirmBar(
                        deleteLabel = deleteRow?.title ?: SettingsStringsExt1.deleteAction.zh,
                        cancelLabel = cancelRow?.title ?: SettingsStringsExt1.cancelAction.zh,
                        onDelete = {
                            // target 取模型写好的那一份（`backdrop.recent.confirmDelete:<key>`），
                            // 渲染层不自己拼第二遍。
                            val target = deleteRow?.actionTarget
                            if (target != null) {
                                onAction(
                                    SettingsAction.WRITE_SETTING,
                                    target,
                                    WallpaperSheetTargets.ROW_RECENT,
                                )
                            }
                            recent.armedKey?.let(recent.onConfirmRemove)
                        },
                        onCancel = recent.onCancelRemove,
                    )
                }

                else -> SettingsNodeView(node = node, onAction = onAction, rowInset = rowInset)
            }
        }
    }
}

/**
 * 面板滚动内容的底部留白 = 系统手势区 + 16dp。
 *
 * Dart 的唯一真源是 `bottomGapInsetOf`（`lib/ui/hyperos/miuix_bottom_sheet.dart:455-458`：
 * `MediaQuery.paddingOf(context).bottom + hyperosMiuixBottomSheetContentBottomGap(16)`）——
 * 能滚动的弹窗把这一截**加在滚动内容里**，而不是垫在滚动视口外面，否则内容滚不进去、
 * 面板底下永远空一块玻璃板（同文件 `:100-111`）。
 *
 * 宿主把它传给 [WallpaperSheetBody] 的 `contentPadding`。
 */
@Composable
fun wallpaperSheetBottomGap(): PaddingValues = PaddingValues(
    bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding() +
        PANEL_CONTENT_BOTTOM_GAP_DP.dp,
)

/** `hyperosMiuixBottomSheetContentBottomGap`（`miuix_bottom_sheet.dart:451`）。 */
private const val PANEL_CONTENT_BOTTOM_GAP_DP = 16.0

/** 壁纸面板状态 → 壁纸流程输入（同一份真源，只换一次形状）。 */
internal fun backdropFlowState(state: AppearanceEditorState): BackdropFlowState =
    BackdropFlowState(
        imagePath = state.wallpaper.path,
        history = state.wallpaper.history.map { it.key },
        followsWeekPager = state.wallpaper.followsWeekPager,
        blurSigma = state.wallpaper.blurSigma,
    )
