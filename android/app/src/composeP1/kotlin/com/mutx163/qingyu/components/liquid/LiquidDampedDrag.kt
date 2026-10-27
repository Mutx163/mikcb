// Copyright 2026, compose-miuix-ui contributors
// SPDX-License-Identifier: Apache-2.0

package com.mutx163.qingyu.components.liquid

// Adapted from Kyant0/AndroidLiquidGlass — https://github.com/Kyant0/AndroidLiquidGlass (Apache 2.0).
//
// 同 [lens]：miuix 0.9.4 发布物里没有它，只在官方 demo 的 `component/animation/` 下。
//
// ## 这是「手感」的核心，不是可选项
//
// 液态玻璃导航栏的**五条**动画（指示器位置、速度、按压进度、X 缩放、Y 缩放）全部由
// 这一个类驱动，而且是五个**独立**的弹簧 —— 这正是它看起来「有生命」的原因：
// 按下去时 X/Y 缩放用不同的刚度（0.6 / 0.7），所以药丸是"稍微拉长"而不是等比缩小；
// 松手时先等位置弹簧落定再收按压，所以不会出现"手指还没松完药丸就弹回去"。
//
// 如果按常规做法只用一个 `animateFloatAsState` 驱动缩放，得到的就是普通 Material
// 组件的死板手感 —— 用户说的「点击效果不对」有一半在这里。

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.spring
import androidx.compose.foundation.MutatorMutex
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.runtime.snapshotFlow
import androidx.compose.runtime.withFrameMillis
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.pointer.AwaitPointerEventScope
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.PointerId
import androidx.compose.ui.input.pointer.PointerInputChange
import androidx.compose.ui.input.pointer.PointerInputScope
import androidx.compose.ui.input.pointer.changedToUpIgnoreConsumed
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.positionChange
import androidx.compose.ui.input.pointer.util.VelocityTracker
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.util.fastFirstOrNull
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlin.math.abs
import kotlin.time.TimeSource

/**
 * 带阻尼的拖拽动画：五通道独立弹簧 + 按下态 + 速度跟踪。
 *
 * @param initialValue 指示器初值（通常是选中下标）。
 * @param valueRange 取值范围（`0f..(itemCount-1)`）。
 * @param visibilityThreshold 动画停止阈值（小于它就算到位）。
 * @param initialScale 静止缩放（通常 1）。
 * @param pressedScale 按下缩放（`GlassDockGeometry.pressScale(...)`）。
 * @param canDrag 某点是否允许起拖（用于排除边缘）。
 * @param onDragStarted 起拖回调（拿到按下点，用来算起始格）。
 * @param onDragStopped 松手回调。
 * @param onDragCancelled 取消回调（默认与松手同）。
 * @param onDrag 拖动中回调（拿到当前尺寸与位移增量）。
 */
internal class DampedDragAnimation(
    private val animationScope: CoroutineScope,
    val initialValue: Float,
    val valueRange: ClosedRange<Float>,
    val visibilityThreshold: Float,
    val initialScale: Float,
    val pressedScale: Float,
    val canDrag: (Offset) -> Boolean = { true },
    val onDragStarted: DampedDragAnimation.(position: Offset) -> Unit,
    val onDragStopped: DampedDragAnimation.() -> Unit,
    val onDragCancelled: DampedDragAnimation.() -> Unit = onDragStopped,
    val onDrag: DampedDragAnimation.(size: IntSize, dragAmount: Offset) -> Unit,
) {

    // 五条通道各自的弹簧。数值来自官方 demo，别随手调：
    // value 用高刚度 1000 保证跟手；velocity 用 300 + 阻尼 0.5（欠阻尼，用来做
    // "甩出去再回来"的过冲）；pressProgress 1.0 阻尼（不回弹，按压不该弹）；
    // scaleX/scaleY 刚度相同但阻尼不同（0.6 / 0.7），这是"稍微拉长"的来源。
    private val valueAnimationSpec = spring(1f, 1000f, visibilityThreshold)
    private val velocityAnimationSpec = spring(0.5f, 300f, visibilityThreshold * 10f)
    private val pressProgressAnimationSpec = spring(1f, 1000f, 0.001f)
    private val scaleXAnimationSpec = spring(0.6f, 250f, 0.001f)
    private val scaleYAnimationSpec = spring(0.7f, 250f, 0.001f)

    private val valueAnimation = Animatable(initialValue, visibilityThreshold)
    private val velocityAnimation = Animatable(0f, 5f)
    private val pressProgressAnimation = Animatable(0f, 0.001f)
    private val scaleXAnimation = Animatable(initialScale, 0.001f)
    private val scaleYAnimation = Animatable(initialScale, 0.001f)

    private val mutatorMutex = MutatorMutex()

    private var pressJob: Job? = null
    private var releaseJob: Job? = null

    private val velocityTracker = VelocityTracker()

    private val startMark = TimeSource.Monotonic.markNow()

    private fun nowMillis(): Long = startMark.elapsedNow().inWholeMilliseconds

    val value: Float get() = valueAnimation.value
    val targetValue: Float get() = valueAnimation.targetValue
    val pressProgress: Float get() = pressProgressAnimation.value
    val scaleX: Float get() = scaleXAnimation.value
    val scaleY: Float get() = scaleYAnimation.value
    val velocity: Float get() = velocityAnimation.value

    val modifier: Modifier = Modifier.pointerInput(Unit) {
        inspectDragGestures(
            onDragStart = { down ->
                onDragStarted(down.position)
                press()
            },
            onDragEnd = {
                onDragStopped()
                release()
            },
            onDragCancel = {
                onDragCancelled()
                release()
            },
        ) { change, dragAmount ->
            // 只有「按下点与当前点都在可拖区域内」才处理：
            // 手指划出栏外时不再驱动指示器（否则会跟着手指跑到屏幕外）。
            val isInside = canDrag(change.position)
            val wasInside = canDrag(change.previousPosition)
            if (isInside && wasInside) {
                onDrag(size, dragAmount)
            }
        }
    }

    /** 按下：五条通道里起三条（按压进度 + 两个方向的缩放）。 */
    fun press() {
        releaseJob?.cancel()
        pressJob?.cancel()
        velocityTracker.resetTracking()
        pressJob = animationScope.launch {
            launch { pressProgressAnimation.animateTo(1f, pressProgressAnimationSpec) }
            launch { scaleXAnimation.animateTo(pressedScale, scaleXAnimationSpec) }
            launch { scaleYAnimation.animateTo(pressedScale, scaleYAnimationSpec) }
        }
    }

    /**
     * 松手：**先等位置弹簧落定**，再收按压。
     *
     * 这个顺序是刻意的：位置还在飞的时候就把按压收掉，会看到药丸"一边飘一边变大"，
     * 像两层动画在打架。等它落定（差值进入 2.5% 量程）再收，读起来是
     * 「先滑到位，再松开」。
     */
    fun release() {
        releaseJob?.cancel()
        releaseJob = animationScope.launch {
            withFrameMillis { }
            if (value != targetValue) {
                val threshold = (valueRange.endInclusive - valueRange.start) * 0.025f
                snapshotFlow { valueAnimation.value }
                    .first { abs(it - valueAnimation.targetValue) < threshold }
            }
            launch { pressProgressAnimation.animateTo(0f, pressProgressAnimationSpec) }
            launch { scaleXAnimation.animateTo(initialScale, scaleXAnimationSpec) }
            launch { scaleYAnimation.animateTo(initialScale, scaleYAnimationSpec) }
        }
    }

    /** 拖拽中直接改目标值（不打断，让弹簧自己追）。 */
    fun updateValue(value: Float) {
        val targetValue = value.coerceIn(valueRange)
        animationScope.launch {
            valueAnimation.animateTo(targetValue, valueAnimationSpec) { updateVelocity() }
        }
    }

    /** 点选切换：按压 → 位移 → 松手，整段连起来播（这样点一下也有"滑过去"的观感）。 */
    fun animateToValue(value: Float) {
        animationScope.launch {
            mutatorMutex.mutate {
                press()
                val targetValue = value.coerceIn(valueRange)
                launch { valueAnimation.animateTo(targetValue, valueAnimationSpec) }
                if (velocity != 0f) {
                    launch { velocityAnimation.animateTo(0f, velocityAnimationSpec) }
                }
                release()
            }
        }
    }

    /** 用位置变化估速度：用来驱动指示器的"甩尾"拉伸。 */
    private fun updateVelocity() {
        velocityTracker.addPosition(nowMillis(), Offset(value, 0f))
        val span = (valueRange.endInclusive - valueRange.start).coerceAtLeast(1e-6f)
        val targetVelocity = velocityTracker.calculateVelocity().x / span
        animationScope.launch(start = CoroutineStart.UNDISPATCHED) {
            velocityAnimation.snapTo(targetVelocity)
        }
    }
}

/**
 * 一个**不吃点击**的拖拽手势检测器。
 *
 * 与 `detectDragGestures` 的区别：这里 `onDragStart` 拿得到按下点（用于算起始格），
 * 且不要求越过 touch slop 才回调 —— 液态玻璃的指示器要在按下那一刻就开始跟手。
 * 点击仍由各条目自己的 `detectTapGestures` 处理（两者不冲突：这个只监听拖动）。
 */
internal suspend fun PointerInputScope.inspectDragGestures(
    onDragStart: (down: PointerInputChange) -> Unit = {},
    onDragEnd: (change: PointerInputChange) -> Unit = {},
    onDragCancel: () -> Unit = {},
    onDrag: (change: PointerInputChange, dragAmount: Offset) -> Unit,
) {
    awaitEachGesture {
        // 两次 awaitFirstDown 是官方做法：第一次在 Initial pass 上拿到"最早"的按下
        // （即使被子节点消费也能看到），第二次才是常规的。少了第一次，
        // 指示器在按下瞬间拿不到起点，跟手会晚一帧。
        val initialDown = awaitFirstDown(false, PointerEventPass.Initial)
        val down = awaitFirstDown(false)
        onDragStart(down)
        onDrag(initialDown, Offset.Zero)
        val upEvent = drag(
            pointerId = initialDown.id,
            onDrag = { onDrag(it, it.positionChange()) },
        )
        if (upEvent == null) {
            onDragCancel()
        } else {
            onDragEnd(upEvent)
        }
    }
}

private suspend inline fun AwaitPointerEventScope.drag(
    pointerId: PointerId,
    onDrag: (PointerInputChange) -> Unit,
): PointerInputChange? {
    val isPointerUp = currentEvent.changes.fastFirstOrNull { it.id == pointerId }?.pressed != true
    if (isPointerUp) return null
    var pointer = pointerId
    while (true) {
        val change = awaitDragOrUp(pointer) ?: return null
        if (change.isConsumed) return null
        if (change.changedToUpIgnoreConsumed()) return change
        onDrag(change)
        pointer = change.id
    }
}

private suspend inline fun AwaitPointerEventScope.awaitDragOrUp(
    pointerId: PointerId,
): PointerInputChange? {
    var pointer = pointerId
    while (true) {
        val event = awaitPointerEvent()
        val dragEvent = event.changes.fastFirstOrNull { it.id == pointer } ?: return null
        if (dragEvent.changedToUpIgnoreConsumed()) {
            // 多指：这一指抬起时若还有别的手指按着，就转去跟那一指，
            // 而不是结束整次拖拽（否则换指会让指示器卡住）。
            val otherDown = event.changes.fastFirstOrNull { it.pressed }
            if (otherDown == null) {
                return dragEvent
            } else {
                pointer = otherDown.id
            }
        } else {
            val hasDragged = dragEvent.previousPosition != dragEvent.position
            if (hasDragged) return dragEvent
        }
    }
}
