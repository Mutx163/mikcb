package com.mutx163.qingyu.pages.timetable.month

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.drag
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.util.VelocityTracker
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp

/**
 * 日历卡**底部拉杆**的尺寸（Dart `MonthGridHandle` 的四个 `static const`，逐值转录）。
 *
 * 为什么不进 [MonthMetrics]：它们是**这个组件私有**的视觉尺寸，不是整页栅格。
 * 卡底另留空白的 [MonthMetrics.CALENDAR_HANDLE_HEIGHT]（26）才是版面常量，
 * 它在共享层里。
 */
object MonthGridHandleMetrics {

    /** 视觉高度（用户截图里那根细条）。 */
    const val BAR_HEIGHT = 5.0

    /** 视觉宽度。截图里约 60（屏宽 393 的 15%），取固定值比取比例好读。 */
    const val BAR_WIDTH = 60.0

    /**
     * 手势**命中**高度：比视觉高得多，手指不必精准点在 5dp 上。
     *
     * 这一条是拉杆能不能用的全部关键 —— Dart 首版把命中区做成 5dp，
     * 真机上根本点不中。
     */
    const val HIT_HEIGHT = 24.0

    /** 细条圆角（Dart `borderRadius: circular(barHeight / 2)`）。 */
    const val BAR_RADIUS = BAR_HEIGHT / 2
}

/**
 * **日历卡的拖拽把手**：卡底正中那根 5dp 小横条。
 *
 * 移植自 `lib/widgets/timetable/month_view/month_grid_handle.dart`（2026-10-27 的
 * 90 行那版）。那两条历史决定的结论（注释里的沿革表）照抄：
 *
 * * 拉杆属于**上半那张日历卡**（语义是「这张卡可以收起」），不是信息列表的把手；
 * * 上滑收日历、下滑放日历，下方信息卡只是跟着让位 —— 回调接到网格收放控制器，
 *   与拉杆画在哪儿无关。
 *
 * ## 回调只给两个量
 *
 * `dy`（位移增量）与 `velocityDy`（抬手纵向速度），单位都是 **dp / dp·s⁻¹**：
 * * 位移 → 进度由 [MonthPanelModel.progressAfterDrag] 算（1:1 跟手，行程恒按
 *   5 行算）；
 * * 吸附由 [MonthPanelModel.settleTarget] 算（甩速 180 优先，否则 0.35 行程翻面）。
 *
 * 不传 `DragUpdateDetails` / `DragEndDetails`：那两个对象里还带着位置、时间戳、
 * 指针类型，渲染层一旦开始从里面挑数字，判据就散回界面层了。
 *
 * @param barColor 细条颜色。它压在**卡片**上（不画在背景上），所以由调用方从
 *   卡片墨色取半透明档传入（[MonthInk.HAIRLINE]），与卡内文字同源。
 */
@Composable
fun MonthGridHandle(
    barColor: Color,
    onDragStart: () -> Unit,
    onDragUpdate: (dy: Float) -> Unit,
    onDragEnd: (velocityDy: Float) -> Unit,
    modifier: Modifier = Modifier,
) {
    val density = LocalDensity.current
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(MonthGridHandleMetrics.HIT_HEIGHT.dp)
            .pointerInput(density) {
                val tracker = VelocityTracker()
                awaitEachGesture {
                    val down = awaitFirstDown(requireUnconsumed = false)
                    tracker.resetTracking()
                    tracker.addPosition(down.uptimeMillis, down.position)
                    onDragStart()
                    drag(down.id) { change ->
                        // 位移取「本次事件相对上次事件」的差，与 Dart 那份
                        // `_onPointerMove` 的 dy 口径一致（不是相对按下点的累计）。
                        val dyPx = change.position.y - change.previousPosition.y
                        tracker.addPosition(change.uptimeMillis, change.position)
                        change.consume()
                        if (dyPx != 0f) {
                            onDragUpdate(with(density) { dyPx.toDp().value })
                        }
                    }
                    // 抬手：速度交给吸附判据（px/s → dp/s，判据常量是 dp 口径）。
                    val velocityDp = with(density) {
                        tracker.calculateVelocity().y.toDp().value
                    }
                    onDragEnd(velocityDp)
                }
            },
        contentAlignment = Alignment.Center,
    ) {
        Box(
            modifier = Modifier
                .size(
                    width = MonthGridHandleMetrics.BAR_WIDTH.dp,
                    height = MonthGridHandleMetrics.BAR_HEIGHT.dp,
                )
                .background(
                    color = barColor,
                    shape = RoundedCornerShape(MonthGridHandleMetrics.BAR_RADIUS.dp),
                ),
        )
    }
}
