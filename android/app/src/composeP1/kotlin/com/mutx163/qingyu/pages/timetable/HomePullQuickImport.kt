package com.mutx163.qingyu.pages.timetable

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.pages.import.ImportStrings
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import top.yukonga.miuix.kmp.basic.PullToRefresh
import top.yukonga.miuix.kmp.basic.rememberPullToRefreshState
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 首页下拉快捷导入被「拉开」之后要干什么——由宿主预备好，页面只负责在收拢后把它交回去。
 *
 * 页面层不认识教务导入、不认识路由、也不弹 Toast：它只知道自己拉到阈值、松手、收拢，
 * 然后把这一份交代原样传给 `onSettled`。跳页与提示都在宿主（`ShellWiring`）里做。
 */
sealed interface HomePullQuickImportPrep {
    /**
     * 备好了：宿主 `commit()` 会发布跨页交接件（待回放的宏），随后自己把用户送到回放页。
     * 之所以拆成「先预备、后提交」，是因为**收拢动画跑完之前不该跳页**，
     * 否则用户看不到「下拉 → 更新中 → 弹回」这三拍。
     */
    class Ready(val commit: () -> Unit) : HomePullQuickImportPrep

    /** 前置没过（没有已存记录 / 没有可用登录地址）：给一句现成文案，不跳页。 */
    class Blocked(val tip: String) : HomePullQuickImportPrep
}

/**
 * 首页周课表的**下拉快捷导入**外壳（对应 Dart `TimetableHomePullSurface` +
 * `TimetableHomePullQuickImportIndicator` 的那一层）。
 *
 * ## 为什么用 miuix 官方 `PullToRefresh` 而不是自己接手势
 *
 * 用户要的六拍（下拉出空白+转圈 → 到阈值震动 → 转「更新中」 → 弹回 → 执行 → 结果）
 * 正是官方组件自带的 `RefreshState` 状态机：
 *
 * | 拍 | 官方落点 |
 * |---|---|
 * | 下拉露空白 + 转圈 | `Pulling`：表头从 0 长出来，环随进度缩放 |
 * | 到阈值震动 | `ThresholdReached`：`RefreshHeader` 里 `HapticFeedbackType.GestureThresholdActivate` |
 * | 转「更新中」 | `Refreshing`：环变成轨道点旋转（`animateRotation`） |
 * | 页面弹回 | `isRefreshing` 落回 false ⇒ `RefreshComplete`（200ms 收拢动画） |
 *
 * 所以这里**不自研动画、不自研手势**：只把「谁来决定跳哪」接出去。
 *
 * ## 为什么会话要等收拢动画跑完才交出去
 *
 * `onPrepare()` 通常只有几毫秒（读一次宏存档），如果它一返回就跳页，用户会看到
 * 「刚震一下页面就被换掉」，弹回那拍完全看不见。这里固定等 [SETTLE_MILLIS]（与官方
 * `RefreshComplete` 的 200ms 同档）再 `onSettled`，让「收拢 → 提示/跳转」顺序稳定。
 *
 * ## 和「凭空拉出一块空白」的关系
 *
 * 旧版首页没有任何下拉实现，手指在顶部继续往下拉时只有 Compose 默认的橡皮筋拉伸，
 * 于是屏幕上出现一条什么都不长的空白。现在这段位移由本组件接住：拉出来的空间里
 * 一定有表头（环 + 文案），松手要么收回、要么进 `Refreshing`，不再出现裸空白。
 *
 * @param enabled 关（设置里没开 / 日视图 / 预览）× 时**完全不装**这层，直接透传内容。
 * @param contentTopInset 指示器要往下让多少（从本层顶边算）。
 *
 *   本层包在**整页**（含顶栏玻璃带）外面，所以顶边就是屏幕顶；指示器默认会画在
 *   状态栏上（2026-11-07 用户实报）。muiix `PullToRefresh` 的 `contentPadding.top`
 *   只下移指示器、不动内容，宿主把「状态栏 + 顶栏 + 星期栏」那条带的高度传进来，
 *   指示器就落在星期栏底下。
 * @param onPrepare 拉过阈值松手后调用：读存档、判前置、备好交代（不跳页）。
 * @param onSettled 收拢动画跑完后调用：提示或跳页。
 */
@Composable
fun HomePullQuickImportHost(
    enabled: Boolean,
    onPrepare: suspend () -> HomePullQuickImportPrep,
    onSettled: (HomePullQuickImportPrep) -> Unit,
    modifier: Modifier = Modifier,
    contentTopInset: Dp = 0.dp,
    content: @Composable () -> Unit,
) {
    if (!enabled) {
        content()
        return
    }
    val pullToRefreshState = rememberPullToRefreshState()
    val scope = rememberCoroutineScope()
    // 长命闭包要读到最新的回调（宿主每次重组都会换新 lambda），否则拿的是首帧那份。
    val currentPrepare by rememberUpdatedState(onPrepare)
    val currentSettled by rememberUpdatedState(onSettled)
    var running by remember { mutableStateOf(false) }

    PullToRefresh(
        // 逻辑真源在宿主：true 期间官方组件把滚动全吃掉并转「更新中」环。
        isRefreshing = running,
        onRefresh = {
            // 已有一次在跑时不叠第二次（官方在 Refreshing 期间也会吞掉滚动，双保险）。
            if (!running) {
                running = true
                scope.launch {
                    val prep = currentPrepare()
                    // 先落回 false：官方据此播 RefreshComplete 收拢（= 用户说的「页面弹回」）。
                    running = false
                    delay(SETTLE_MILLIS)
                    currentSettled(prep)
                }
            }
        },
        modifier = modifier,
        pullToRefreshState = pullToRefreshState,
        // 只下移指示器（官方语义）：正文仍从本层顶边开始，页内布局不受影响。
        contentPadding = PaddingValues(top = contentTopInset),
        // 环色走主题强调色：白底、深底、壁纸上都看得见（R5：不写死色值）。
        color = MiuixTheme.colorScheme.primary,
        refreshTexts = PULL_REFRESH_TEXTS,
        refreshTextStyle = MiuixTheme.textStyles.body2,
        content = {
            Box(modifier = Modifier.fillMaxSize()) { content() }
        },
    )
}

/**
 * 四拍文案：拖动中 / 到阈值 / 更新中 / 完成。
 *
 * 前两拍留空是**故意的**——用户要的是「露出空白 + 转圈」，环本身已经说明一切；
 * 一旦有字，收拢时那行字会在 200ms 里闪一下，反而脏。更新中那拍才用 ARB 原文
 * 「正在获取新课程……」（Dart `homePullQuickImportFetchingCourses` 同一句）。
 */
private val PULL_REFRESH_TEXTS: List<String> = listOf(
    "",
    "",
    ImportStrings.homePullQuickImportFetchingCourses.text,
    "",
)

/** 与官方 `RefreshComplete` 的 200ms 收拢动画同档，留一点余量免得字还没淡完就跳页。 */
private const val SETTLE_MILLIS = 220L
