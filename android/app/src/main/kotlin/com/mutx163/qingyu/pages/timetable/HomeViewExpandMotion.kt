package com.mutx163.qingyu.pages.timetable

import kotlin.math.max
import kotlin.math.roundToInt

/**
 * 首页「周视图 ↔ 日视图」转场的纯几何与时长（2026-11-02 补）。
 *
 * ## 为什么需要它
 *
 * Flutter 原版的日视图**不是一页路由**，而是首页内部的一种展开态：
 * 点星期栏某一天，选中那一列从网格列位向左右长到整屏（`morphColumnsLayout` /
 * `timetable_anchored_day_overlay.dart` 的窗口收放）。Compose 迁移后把日视图做成了
 * 独立页面（`c3.day`），周→日变成「推一页」、底栏周/日切换变成「替换栈底」，
 * 观感是左右滑入 —— 与原版差得很远。
 *
 * 现在改为：周 / 日共用同一个首页宿主，日视图作为**同一页内的展开层**，
 * 由本文件算出「展开窗口」的左右边界。几何规则只有这一份，渲染层不许另写公式。
 *
 * ## 坐标系
 *
 * 全部是**首页根布局**的像素坐标（原点 = 屏幕左上角；页面在 NavDisplay 条目里铺满，
 * 所以也就是屏幕坐标）。左边界到 0、右边界到 [viewportWidth] 即「日视图铺满」。
 *
 * ## 与旧「面板拉伸」的区别
 *
 * 展开层里放的是一张**已经按整屏排好版的日视图**（内容不重排、字号不变），
 * 这里只算裁切窗口 —— 不是把窄面板横向拉伸（那会让文字变形，Dart 原版
 * 2026-10-21 已明确否掉那一版）。
 */
data class HomeViewExpandWindow(
    /** 窗口左边界（根布局像素）。 */
    val left: Float,
    /** 窗口右边界（根布局像素，不含）。 */
    val right: Float,
) {
    val width: Float get() = max(0f, right - left)
}

/**
 * 算某一帧的展开窗口。
 *
 * - `progress == 0`：窗口 = 选中日那一列（时间列右侧、第 `index` 天）；
 * - `progress == 1`：窗口 = 整屏（`0 .. viewportWidth`）；
 * - 中间：左右边界分别线性插值 —— 选中列向两侧同时让开，读起来是「这一列长成整屏」。
 *
 * 邻居列保持原宽（不参与计算）：它们由底下的周视图自己画，日视图展开层只盖住窗口。
 *
 * @param progress 0..1（已过曲线的值）。超出范围会被夹住。
 * @param viewportWidth 首页根布局宽度（像素）。
 * @param contentLeft 课表内容区左边界（安全区内缩之后，根布局像素）。
 * @param contentWidth 课表内容区宽度（安全区内缩之后，像素）。
 * @param timeColumnWidth 周视图左侧时间列宽（像素）。
 * @param visibleDays 可见星期（1 = 周一），顺序即列顺序。
 * @param selectedDayOfWeek 选中的星期（1..7）。不在 [visibleDays] 里时取第 0 列。
 */
fun homeViewExpandWindow(
    progress: Float,
    viewportWidth: Float,
    contentLeft: Float,
    contentWidth: Float,
    timeColumnWidth: Float,
    visibleDays: List<Int>,
    selectedDayOfWeek: Int,
): HomeViewExpandWindow {
    val t = progress.coerceIn(0f, 1f)
    val days = visibleDays.size.coerceAtLeast(1)
    val gridWidth = max(1f, contentWidth - timeColumnWidth)
    val dayWidth = max(1f, gridWidth / days)
    val index = visibleDays.indexOf(selectedDayOfWeek).let { if (it < 0) 0 else it }
    val columnLeft = contentLeft + timeColumnWidth + index * dayWidth
    val columnRight = columnLeft + dayWidth
    val left = columnLeft + (0f - columnLeft) * t
    val right = columnRight + (viewportWidth - columnRight) * t
    return HomeViewExpandWindow(left = left, right = max(left + 1f, right))
}

/**
 * 转场时长：Flutter `DayViewExpandMotion.baseMilliseconds = 210`，按用户
 * 「页面转场速度」倍率缩放（**速度越大、时长越短**，与壳里 `scaledToUserSpeed` 同口径）。
 *
 * 倍率区间 0.5~2.5 与设置滑杆一致；夹紧后再算，避免 0 或负数把时长打成 0。
 */
fun homeViewExpandDurationMillis(speed: Double): Int {
    val clamped = speed.coerceIn(0.5, 2.5)
    return (210.0 / clamped).roundToInt().coerceAtLeast(1)
}

/**
 * 「减少动画」降级判据（2026-11-03 补齐，此前 Flutter 有、Compose 迁移漏了）。
 *
 * 对齐 Flutter `DayViewExpandMotion.reduceMotion`
 * （`lib/ui/hyperos/day_view_expand_motion.dart:92-102`）与它的展开/收起两个落定分支
 * （同文件 `expand`/`collapse`，:128-149）：系统开启「减少动画」时**不播逐帧形变**，
 * 展开直接落到 1、收起直接落到 0。理由不是省算力——开这个开关的用户（前庭功能障碍）
 * 对任何逐帧运动都敏感，「短一点的动画」也还是动画。
 *
 * 系统来源：Flutter 读 `MediaQuery.disableAnimations`；Android 上同一开关的系统表达
 * 是「动画时长缩放」归零（`Settings.Global.ANIMATOR_DURATION_SCALE == 0`，开发者选项里
 * 三个动画缩放一起关时的那一份）。判据取值放这里保持纯函数（JVM 可测），Android 侧的
 * 实际读取在渲染层薄适配（`TimetableWeekPage` 读完传进来），本文件不 import android。
 *
 * `scale < 0` 现实中不存在，但按「不开动画」处理（与 `<= 0` 同一边），测试钉住这一边。
 */
fun homeViewExpandReducedMotion(animatorDurationScale: Float): Boolean = animatorDurationScale <= 0f

/**
 * 展开窗口的**种子圆角**（逻辑 dp）。
 *
 * 取值出处：Flutter `HyperosMiuixNavigation.anchorExpandRadius`
 * （`lib/ui/hyperos/hyperos_navigation.dart:162-174`）——锚点展开的种子面板 28dp，
 * 起手保持满值，长到贴边后才收平。2026-11-03 用户真机口径：直角切口「廉价、丑陋」，
 * 圆角形变窗口（照抄 miuix 官方下拉形变的 RoundRect 插值技法）替换直角 clipRect。
 */
const val HOME_VIEW_EXPAND_SEED_CORNER_DP = 28f

/**
 * 圆角收束带宽：**缓动后**进度的最后 [HOME_VIEW_EXPAND_CORNER_SETTLE_BAND] 一段里
 * 把圆角从满值收平到 0。
 *
 * 取值出处：Flutter `HyperosMiuixNavigation.anchorExpandCornerSettleBand = 0.002`
 * （`lib/ui/hyperos/hyperos_miuix_spec.dart:884`）。
 */
const val HOME_VIEW_EXPAND_CORNER_SETTLE_BAND = 0.002f

/**
 * 形变转场的圆角收束因子（0 = 平角，1 = 满半径）：**只收尾、不起头**。
 *
 * 逐点对齐 Flutter `HyperosMiuixNavigation.morphCornerRadiusFactor`
 * （`lib/ui/hyperos/hyperos_navigation.dart:141-151`）：起手是一张带圆角的种子面板，
 * 圆角全程保持满值；只有「窗口已经长到贴边」之后的收尾带宽内才线性收平。
 *
 * 反面教材（同一函数 KDoc 里 Flutter 侧 2026-10-17 真机记录）：从 0 起就按进度线性收
 * （`28 × (1 - p)`）会在页面还差十分之一屏宽没贴边时圆角就没了——用户原话
 * 「页面还没有完全贴边的时候，圆角就已经消失变成直角了」。
 *
 * @param progress **曲线作用后**的展开进度（0..1）。超出会被夹住。
 * @param band 收尾带宽（缓动后进度占比）；`<= 0` 退化为二值开关（只在端点收平）。
 */
fun homeViewExpandCornerRadiusFactor(
    progress: Float,
    band: Float = HOME_VIEW_EXPAND_CORNER_SETTLE_BAND,
): Float {
    val clamped = progress.coerceIn(0f, 1f)
    if (band <= 0f) {
        return if (clamped >= 1f) 0f else 1f
    }
    return ((1f - clamped) / band).coerceIn(0f, 1f)
}

/** 挡输入阈值：展开进度低于它时，展开层不拦事件（Dart
 * `timetable_anchored_day_overlay.dart:231-235` 的 `ignoring: progress < 0.05` 同口径
 * ——收起尾段窗口只剩一条细缝，点按应该落到下面还看得见的周网格上）。
 */
const val HOME_VIEW_EXPAND_INPUT_GATE = 0.05f
