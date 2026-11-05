package com.mutx163.qingyu.pages.timetable.month

import androidx.compose.foundation.gestures.animateScrollBy
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.awaitVerticalTouchSlopOrCancellation
import androidx.compose.foundation.gestures.drag
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.util.VelocityTracker
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

/**
 * 面板拖拽的接线盒：网格收放的三件回调 + 面板列表的滚动状态。
 *
 * 由页面 `remember` 一次、同时交给 [MonthPanelDragArea] 与拉杆
 * （[MonthGridHandle]）——**同一份判据驱动两条手势入口**，这样「拉杆往下拖」与
 * 「面板任意位置往下拖」的手感必然一致（Dart 侧也是同一个 `_beginGridDrag` 接线）。
 */
@Stable
class MonthPanelDragState {

    /**
     * 面板列表（议程态才有；概览态传 null）。
     *
     * 必须由页面**显式**设置：Dart 侧正是靠 `scrollController.hasClients` 区分
     * 「概览态没有滚动视图」—— 那种树上无条件 `jumpTo` 会直接断言失败
     * （2026-10-25 收起态实测：手指一碰就抛）。这里用 null 表达同一件事。
     */
    var listState: LazyListState? = null

    /** 网格还能不能往这个方向继续收放（负 = 收起方向、正 = 展开方向）。 */
    var gridCanAbsorb: (dy: Float) -> Boolean = { false }

    /** 本次手势里网格第一次吃到位移（页面据此停动画、记起点）。 */
    var onCollapseStart: () -> Unit = {}

    /** 拖拽中：位移增量（dp，向上为负）。 */
    var onCollapseUpdate: (dy: Float) -> Unit = {}

    /** 抬手：纵向速度（dp/s），交给吸附判据。 */
    var onCollapseEnd: (velocityDy: Float) -> Unit = {}
}

/**
 * 面板纵向拖拽：**一个指针源，同时驱动「网格收放」与「列表滚动」**。
 *
 * 移植自 `lib/widgets/timetable/month_view/month_panel_drag_area.dart`（2026-10-27
 * 的 307 行那版）。那份文件的类注释记着两版失败实现的死因，这里只留结论：
 *
 * > 只要「面板高度」在同一次手势里变化，就不能让 `Scrollable` 自己滚。
 * > 所以列表的**用户滚动整个关掉**（调用方传 `userScrollEnabled = false`），
 * > 位移一律由本组件算好、用 `dispatchRawDelta` 落到列表上。
 *
 * 于是：只有一个指针源 ⇒ 两块内容**必然**按同一顺序动，一体化是结构保证的；
 * 面板高度变化时不再有「进行中的 ScrollActivity」可被打断。
 *
 * ## 顺序（用户口径那张表）
 *
 * | 手势 | 第一优先 | 之后 |
 * |---|---|---|
 * | 向上拖（dy < 0，看下面） | 网格收起（进度 → 0） | 收到底后滚列表 |
 * | 向下拖（dy > 0，往回看） | 列表退回顶部 | 到顶后网格展开（进度 → 1） |
 *
 * 判据在 [MonthPanelDragRouting.collapseTakesPriority]（纯函数、有单测），
 * 本组件只负责「取位移 → 问判据 → 分派 → 补惯性」。
 *
 * ## 与点击共存（2026-11-05 修）
 *
 * 旧实现 `awaitFirstDown` 之后直接 `drag()`：**没有触摸阈值**，而且每个 move 都
 * `change.consume()`。这层里面装的正是可点内容（`MonthPanelRow` 的行、日期格），
 * 而 Compose 的 `clickable` 在 Final pass 一看到位移被别人消费就判定「这不是点击」，
 * 于是手指带一丁点抖动，这一下点击就被吃掉 —— 表现为「概览行 / 议程行有时候点不动」。
 *
 * 现在与 `detectVerticalDragGestures` 同一条纪律：
 * 1. **越过纵向 touch slop 才接管**（[awaitVerticalTouchSlopOrCancellation]），
 *    越过之前一个事件都不消费，点击留给下面的行；
 * 2. 只消费**判据真正取用**的那段位移（归网格 / 归列表且列表确实滚动了）；
 *    谁都不接的位移（例如列表已在顶端还要往下拖）原样放过去，不消费。
 *
 * ## 为什么不用手势竞技场分工
 *
 * 两者同向，竞技场只会有一个赢家：要么列表永远滚不动、要么网格永远收不起来；
 * 而且赢家取决于「谁先接受」，与「用户此刻想看哪段」无关。
 */
@Composable
fun MonthPanelDragArea(
    state: MonthPanelDragState,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    val density = LocalDensity.current
    val scope = rememberCoroutineScope()

    Box(
        modifier = modifier.pointerInput(state, density) {
            val tracker = VelocityTracker()
            // 这两个 flag 只活在这个 pointerInput 协程里：一次手势期间有效，
            // 与 Dart 那份 State 上的同名字段同义（判断「抬手要不要吸附/补惯性」）。
            var gridTouched = false
            var listTouched = false
            var flingJob: Job? = null

            /**
             * 把一段位移按判据分派出去，返回「这段位移是否被我们真的用掉」。
             *
             * 返回值就是「要不要 `consume()`」：没用掉就别消费，让事件照常往下/往上走
             *（例如列表已经到顶、网格也展开到头时，这段拖动谁也不接，不该被这里吃掉）。
             */
            fun dispatchDelta(dyPx: Float): Boolean {
                if (dyPx == 0f) return false
                val dyDp = with(density) { dyPx.toDp().value }

                val list = state.listState
                val listCanScroll = list != null && MonthPanelDragRouting.listCanScroll(
                    dy = dyDp.toDouble(),
                    canScrollForward = list.canScrollForward,
                    canScrollBackward = list.canScrollBackward,
                )
                val toGrid = MonthPanelDragRouting.collapseTakesPriority(
                    dy = dyDp.toDouble(),
                    listCanScroll = listCanScroll,
                    gridCanAbsorb = state.gridCanAbsorb(dyDp),
                )

                if (toGrid) {
                    if (!gridTouched) {
                        gridTouched = true
                        state.onCollapseStart()
                    }
                    state.onCollapseUpdate(dyDp)
                    return true
                }

                if (list == null) return false
                // 手指向下（dyPx > 0）⇒ 内容回退 ⇒ pixels 减小，故取负号。
                // dispatchRawDelta 是同步的，且它自己会在边界截断。
                val consumed = list.dispatchRawDelta(-dyPx)
                if (consumed == 0f) return false // 列表到边界：这段不归我们，不消费
                listTouched = true
                return true
            }

            awaitEachGesture {
                val down = awaitFirstDown(requireUnconsumed = false)
                // 按下即接管：正在跑的惯性立刻停住（用户伸手就是要自己控）。
                flingJob?.cancel()
                flingJob = null
                gridTouched = false
                listTouched = false
                tracker.resetTracking()
                tracker.addPosition(down.uptimeMillis, down.position)

                // ── 先过 slop 再接管（2026-11-05）──
                // 越过阈值之前**不消费任何事件**：这层下面是可点的行与日期格，
                // 提前 consume 会让 clickable 在 Final pass 判定点击取消。
                // 阈值内那点位移（overSlop）先记账，接管后补上，避免「起手丢几像素」。
                var overSlopPx = 0f
                val crossing = awaitVerticalTouchSlopOrCancellation(down.id) { change, overSlop ->
                    change.consume()
                    overSlopPx += overSlop
                }
                // 抬手（点击）或被判成横向滑动：不接管、不消费，交回下面的行。
                if (crossing == null) return@awaitEachGesture

                tracker.addPosition(crossing.uptimeMillis, crossing.position)
                dispatchDelta(overSlopPx)

                drag(crossing.id) { change ->
                    // 取「本次相对上次」的增量（与 Dart `_onPointerMove` 的 dy 同口径）。
                    val dyPx = change.position.y - change.previousPosition.y
                    tracker.addPosition(change.uptimeMillis, change.position)
                    val used = dispatchDelta(dyPx)
                    if (used) change.consume()
                }

                val velocityDp = with(density) { tracker.calculateVelocity().y.toDp().value }
                if (gridTouched) {
                    // 网格吃过位移 → 按速度吸附到两端。
                    state.onCollapseEnd(velocityDp)
                }
                if (listTouched) {
                    // 列表的用户滚动被关掉了，惯性得自己补一段（Dart 的 _startListFling）。
                    //
                    // ⚠️ 这里必须**重新取一次** listState：上面那个 `list` 是 drag 回调
                    // 里的局部变量，出了 `drag { }` 就出作用域了（L1 报过 Unresolved
                    // reference 'list'）。
                    val list = state.listState
                    val deltaDp = MonthPanelDragRouting.flingDelta(velocityDp.toDouble())
                    if (list != null && deltaDp != 0.0) {
                        flingJob = scope.launch {
                            // animateScrollBy 的正方向与 dispatchRawDelta 的 delta 同向：
                            // dy 为正（内容回退）要往回滚，故取负。
                            list.animateScrollBy(with(density) { (-deltaDp).toFloat().dp.toPx() })
                        }
                    }
                }
            }
        },
    ) {
        content()
    }
}
