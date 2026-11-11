package com.mutx163.qingyu.pages.timetable

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.glass.courseCardGlassSurface
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.pages.settings.HomeMaterialRenderSpec
import com.mutx163.qingyu.pages.settings.SurfaceMaterialState
import com.mutx163.qingyu.pages.timetable.day.DayViewStrings
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.blur.Backdrop
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Alarm
import top.yukonga.miuix.kmp.icon.extended.Tasks
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 周视图课卡的几何常量（Dart `course_card.dart:_buildCompactCard` 的紧凑卡口径）。
 *
 * **为什么写常量而不是直接 `8.dp`**：这些是**复刻 Dart 版式**的几何量（圆角 8、
 * 内边距 4/4~6、行距 2、字号 9/8/7），不是随手挑的间距。集中成常量既能让
 * 单测钉住，也避免「写死字号」的守卫（R4）把几何口径当成绕过主题。
 */
object WeekCardMetrics {
    /** 卡面圆角（Dart `_buildCompactCard` 的 `borderRadius: 8`）。 */
    const val CORNER_RADIUS_DP = 8f

    /** 卡面与格子之间的外缩（真实值来自设置 `timetableCourseCardGap`，这里是兜底）。 */
    const val OUTER_INSET_DP = 1.25f

    /** 内容左右内边距（Dart `horizontal: 4`）。 */
    const val INNER_HORIZONTAL_DP = 4f

    /** 内容上下内边距：矮格 4、常规 6（Dart `sectionHeight < 64 ? 4 : 6`）。 */
    const val INNER_VERTICAL_COMPACT_DP = 4f
    const val INNER_VERTICAL_REGULAR_DP = 6f

    /** 文字行距（Dart `SizedBox(height: 2)`）。 */
    const val LINE_GAP_DP = 2f

    /** 详情字号 = 标题字号 - 1（Dart `compactSubtitleFontSize`），并 clamp 到 7..14。 */
    fun detailFontSize(titleFontSize: Float): Float =
        (titleFontSize - 1f).coerceIn(7f, 14f)

    /** 角标/小字字号 = 详情 - 1，clamp 到 6..12（Dart overline 口径）。 */
    fun overlineFontSize(detailFontSize: Float): Float =
        (detailFontSize - 1f).coerceIn(6f, 12f)
}

/**
 * 安全解析 16 进制颜色串，失败时回退到 [fallback]。
 */
fun parseHexColor(hex: String?, fallback: Color = Color(0xFF2196F3)): Color {
    if (hex.isNullOrBlank()) return fallback
    val cleaned = hex.trim()
    return try {
        Color(android.graphics.Color.parseColor(if (cleaned.startsWith("#")) cleaned else "#$cleaned"))
    } catch (_: Throwable) {
        fallback
    }
}

/**
 * 根据背景色计算高对比前景色（深色底配白字，浅色底配深墨色）。
 */
fun calculateInk(backgroundColor: Color): Color {
    val luminance = 0.299 * backgroundColor.red + 0.587 * backgroundColor.green + 0.114 * backgroundColor.blue
    return if (luminance > 0.55) Color(0xFF1E293B) else Color.White
}

/**
 * 周网格课程卡片（对应 Dart `lib/widgets/course_card.dart` 的紧凑卡分支）。
 *
 * ## 这一版按 Dart 逐项复刻（2026-10-29 重做）
 *
 * 旧卡片的四个问题，逐条对上 Dart 后修掉：
 * 1. **不读设置**：内容行（课名/教师/地点/时间/周次/简介）现在全部由 [WeekViewStyle]
 *    的七个开关控制；字号取 `courseCardFontSize`（默认 9/8），不再用 13sp 的
 *    `footnote2`（那比 Dart 大一半，卡片里放不下三行）；
 * 2. **角标语义错**：Dart 的「非本周」是左上角**小字**（不是胶囊），「冲突」同时
 *    出现为左上小字 + 右上角标（`showConflictBadgeOnTimetable` 可关）；
 * 3. **非本周透明度**：Dart 固定 0.62（旧值 0.45 太淡，看着像禁用了）；
 * 4. **圆角 16/10dp**：Dart 是 8dp；卡与格子之间只有约 1.25dp 的外缩。
 *
 * ## 刻意没做的（已在审计里记账，不是遗忘）
 *
 * - 天气行（`CourseWeatherDisplay`）：Compose 侧天气数据还没接进课表宿主，见
 *   `docs/plans/2026-10-29-compose-week-view-audit.md` 的 P1-1（课卡天气行）；
 * - 高斯/液态玻璃卡面的**降级**：没有壁纸、模糊总闸关或设备不支持 runtime shader 时，
 *   两档都退化成半透明实体（与 Dart 无壁纸时一致）。**液态档已接真采样 + 模糊 + 折射**
 *   （折射 2026-11-01 补）：卡片从整页共享的预糊层取背景（见 [glassBackdrop]），
 *   不是每卡一次实时模糊；边缘折射与色散走 miuix `lens()`，参数取**卡片自己那套**
 *   （`courseCardRefraction` / `courseCardRefractionBand` / `courseCardDispersion`）。
 *   **仍未接**（官方 API 没有对应物，不是遗忘）：
 *   `refractionEdgePow` —— miuix 镜片的截面写死是圆弧（`LiquidLens.kt` 的 `circleMap`），
 *   没有「圆弧之上的陡缓指数」这根旋钮，只有默认值 2.5 恰好等于圆弧那一点能对上；
 *   边缘高光 `rimStrength` / `rimWidth` —— miuix 的边光是 `drawBackdrop(highlight = …)`
 *   的 BloomStroke，与 Dart 着色器里那条「峰在带内的整圈均匀鼓包」不是同一个机制，
 *   接它是一次独立的观感决定（会多出一条带光来向的白描边）；
 * - 每行的 flex 比例（Dart 用 `flex: 4/2/3` 分配高度）：这里用 maxLines + 省略号，
 *   视觉接近，但「格子很高时各行按比例拉长」这层没有。
 */
@Composable
fun CourseGridCard(
    model: WeekCardModel,
    style: WeekViewStyle,
    sectionHeight: Dp,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    /**
     * 卡面高亮。**周视图不要接线**：发布版周网格（Dart）虽然写着
     * `isHighlighted: item.isCurrentCourse`（`v2.1.4.1:lib/screens/timetable_screen.dart:4653`），
     * 但那一列取 items 时没传 `currentCourseIds`（`:3318-3324`，形参默认空集 `:5033`）
     * ⇒ 发布版里它恒为 false，是一条死路径。要让它亮属于产品变更（发布版周视图不高亮），
     * 需拍板 + 真机对照，不是补漏。
     */
    isHighlighted: Boolean = false,
    isHoliday: Boolean = false,
    /**
     * 材质快照（`SettingsMaterialModel.renderSpecOf`）。null = 老口径
     * （只看 [WeekViewStyle.surfaceStyle]）。
     *
     * 2026-11-01 之前：材质面板改「默认材质（实体/液态）」、卡片那档的染色旋钮
     * 全都只落盘不上屏 —— 因为这里只读 `style.surfaceStyle`，而它不含总闸与无壁纸降级。
     */
    material: HomeMaterialRenderSpec? = null,
    /**
     * 液态档的**整页共享**背景采样源（`TimetableWeekPage.cardGlassBackdrop`）。
     *
     * 非空 = 宿主已建好一层壁纸录像（σ > 0 时还叠了一层「整屏预糊」），
     * 所有卡片都从这一层取自己那块像素；null = 保留原有的透明度填充。
     * 一屏 20~50 张卡**共用一层**，不给每张卡建采样层（Dart
     * `course_surface.dart:197-208` 同一条性能口径）。
     */
    glassBackdrop: Backdrop? = null,
) {
    val course = model.course
    val dark = isSystemInDarkTheme()
    val rawColor = parseHexColor(model.colorHex ?: course.color, fallback = Color(0xFF2196F3))
    // 卡面透明度：Dart 的 `surfaceOpacity` 是冲突/非本周的压淡系数，直接乘在填充上。
    //
    // 有材质快照时按**生效档**取（Dart `effectiveCourseCardSurfaceStyle`）：
    // * 实体（总闸关 / 无壁纸 / 用户选实体）→ 不透明课色；
    // * 高斯档 → 0.55 课色（Compose 侧没有预糊位图管线，这是无模糊的降级观感）；
    // * 液态档 → 卡片自己那套调参的 `tintAlpha`（Dart `CourseSurface.washAlpha` 同口径）。
    val fillAlpha = when (material?.courseCard) {
        SurfaceMaterialState.SOLID, SurfaceMaterialState.OFF -> model.opacity
        SurfaceMaterialState.FROST_GAUSSIAN, SurfaceMaterialState.FROST ->
            0.55f * model.opacity
        SurfaceMaterialState.LIQUID_GLASS ->
            (material?.courseCardTintAlpha ?: 0.70f).coerceIn(0.08f, 1f) * model.opacity
        // 渐进模糊与「没传材质」都回旧口径（课卡不会用渐进档，防御性分支）。
        SurfaceMaterialState.FROST_PROGRESSIVE, null -> when (style.surfaceStyle) {
            WeekCardSurface.SOLID -> model.opacity
            WeekCardSurface.TRANSLUCENT -> 0.72f * model.opacity
            // 没有壁纸/模糊管线时 Dart 也退化成半透明实体（`effectiveCourseCardSurfaceStyle`）。
            WeekCardSurface.GAUSSIAN -> 0.55f * model.opacity
        }
    }
    val fill = rawColor.copy(alpha = fillAlpha.coerceIn(0.08f, 1f))
    // ── 墨色：设置里的「课卡标题色 / 详情色」（2026-10-29 二轮修复 P1-11）──
    // 判据在模型层 CourseCardInk（Dart `course_color_palette.dart:352-408`）：
    // 用户色与卡面对比度 ≥ 2.0 才采用，否则回落到白/近黑里对比度更高的一档；
    // 详情墨再把明暗极性对齐标题墨、统一 0.7 alpha。
    // 以前这里用 `calculateInk(rawColor)` 自算，于是那四个设置**改了没反应**。
    // 用户自己给课程挑的字色（`course.textColor`）优先于设置默认值——Dart 同序。
    val preferredTitleArgb = course.textColor?.let(::parseArgbOrNull)
        ?: parseArgbOrNull(if (dark) style.cardTitleColorDark else style.cardTitleColorLight)
    val preferredDetailArgb = parseArgbOrNull(
        if (dark) style.cardDetailColorDark else style.cardDetailColorLight,
    )
    val cardArgb = rawColor.toArgb()
    val ink = Color(CourseCardInk.resolveTitleInk(preferredTitleArgb, cardArgb))
    val (detailArgb, detailAlpha) = CourseCardInk.resolveDetailInk(
        preferred = preferredDetailArgb,
        resolvedTitleInk = ink.toArgb(),
        cardColor = cardArgb,
    )
    val detailInk = Color(detailArgb).copy(alpha = detailAlpha)

    val titleFontSize = style.cardTitleFontSize
    val detailFontSize = WeekCardMetrics.detailFontSize(titleFontSize)
    val overlineFontSize = WeekCardMetrics.overlineFontSize(detailFontSize)
    val shape = RoundedCornerShape(WeekCardMetrics.CORNER_RADIUS_DP.dp)
    val span = model.sectionSpan
    val innerVerticalPadding = if (sectionHeight < 64.dp) {
        WeekCardMetrics.INNER_VERTICAL_COMPACT_DP
    } else {
        WeekCardMetrics.INNER_VERTICAL_REGULAR_DP
    }

    // 2141 简单面板：不再有逐卡飞行；保留一个空修饰器占位，避免大改每行文字的调用点。
    @Suppress("UNUSED_PARAMETER")
    fun flightAnchor(
        lineId: String,
        text: String,
        fontSizeSp: Float,
        weight: FontWeight,
        anchorInk: Color,
        maxLines: Int = 1,
        lineHeightSp: Float = 0f,
    ): Modifier = Modifier

    // Dart 的压淡：停课 0.4、假期 0.3（`CourseCard.build` 顶部的 Opacity 分支）。
    val dim = when {
        model.isSuspended -> 0.4f
        isHoliday -> 0.3f
        else -> 1f
    }

    val borderModifier = if (isHighlighted) {
        Modifier.border(1.2.dp, Color.White.copy(alpha = 0.9f), shape)
    } else {
        Modifier
    }

    // ── 液态档：真背景采样（2026-11-01）──
    // 只有「宿主给了共享采样层 + 生效档确实是液态」才走这条路；其余一律回落到
    // 下面的 `.background(fill)`（无壁纸 / 总闸关 / 无 shader / 实体 / 高斯档）。
    //
    // 采样层由宿主建好并**整页共用**；这里每张卡只付一次矩形采样，高斯已经在共享
    // 层里糊过一次 —— **不是**每卡一次实时模糊（那正是 Dart 注释里把课表拖到
    // 十几帧的元凶）。成本不随卡片数量线性涨。
    val cardBackdrop = glassBackdrop?.takeIf {
        material?.courseCard == SurfaceMaterialState.LIQUID_GLASS
    }
    // ── 液态档折射 / 高光统一走共享卡面件（2026-11-04）──
    // 与日视图各卡**同一份** `courseCardGlassSurface`：折射三参取卡片自己那套
    //（`material.courseCardRefraction/Band/Dispersion`），边光走 `glassRimAlpha`。
    // 采样源仍是整页共享的预糊壁纸层（不改实时内容，否则把卡后文字糊进卡面）。
    // 课色染在模糊后的背景上：`fill` 的 alpha 就是 `courseCardTintAlpha`（× 压暗）。
    val surfaceModifier = if (cardBackdrop != null) {
        Modifier.courseCardGlassSurface(
            backdrop = cardBackdrop,
            shape = shape,
            fill = fill,
            material = material,
        )
    } else {
        Modifier.background(fill)
    }

    Box(
        modifier = modifier
            .padding(style.cardInsetDp.dp)
            .fillMaxSize()
            .alpha(dim)
            .clip(shape)
            .then(surfaceModifier)
            .then(borderModifier)
            .clickable(onClick = onClick),
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(
                    horizontal = WeekCardMetrics.INNER_HORIZONTAL_DP.dp,
                    vertical = innerVerticalPadding.dp,
                ),
            verticalArrangement = when (style.verticalAlign) {
                WeekCardVerticalAlign.TOP -> Arrangement.Top
                WeekCardVerticalAlign.CENTER -> Arrangement.Center
                WeekCardVerticalAlign.BOTTOM -> Arrangement.Bottom
                WeekCardVerticalAlign.SPACE_EVENLY -> Arrangement.SpaceEvenly
            },
            horizontalAlignment = when (style.horizontalAlign) {
                WeekCardHorizontalAlign.LEFT -> Alignment.Start
                WeekCardHorizontalAlign.CENTER -> Alignment.CenterHorizontally
                WeekCardHorizontalAlign.RIGHT -> Alignment.End
            },
        ) {
            val textAlign = when (style.horizontalAlign) {
                WeekCardHorizontalAlign.LEFT -> TextAlign.Start
                WeekCardHorizontalAlign.CENTER -> TextAlign.Center
                WeekCardHorizontalAlign.RIGHT -> TextAlign.End
            }

            // ── 左上角小字（非本周 / 冲突），Dart `compactOverlineText` ──
            val overline = when (model.overline) {
                WeekCardOverline.NON_CURRENT_WEEK -> TimetableStrings.nonCurrentWeekLabel.text
                WeekCardOverline.CONFLICT -> TimetableStrings.conflictLabel.text
                null -> null
            }
            if (overline != null) {
                Text(
                    text = overline,
                    style = MiuixTheme.textStyles.footnote2,
                    fontSize = overlineFontSize.sp,
                    color = detailInk,
                    textAlign = textAlign,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = flightAnchor(
                        "overline",
                        overline,
                        overlineFontSize,
                        FontWeight.Normal,
                        detailInk,
                    ),
                )
                Spacer(modifier = Modifier.height(WeekCardMetrics.LINE_GAP_DP.dp))
            }

            var hasAnyField = false

            if (style.showName) {
                hasAnyField = true
                val nameMaxLines = if (span >= 3) 4 else if (span >= 2) 3 else 2
                Text(
                    text = course.name,
                    style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.BOLD),
                    fontSize = titleFontSize.sp,
                    color = ink,
                    textAlign = textAlign,
                    maxLines = nameMaxLines,
                    overflow = TextOverflow.Ellipsis,
                    modifier = flightAnchor(
                        "name",
                        course.name,
                        titleFontSize,
                        FontWeight.Bold,
                        ink,
                        maxLines = nameMaxLines,
                    ),
                )
            }
            if (style.showTeacher && course.teacher.isNotBlank()) {
                hasAnyField = true
                CardDetailLine(
                    text = course.teacher.trim(),
                    fontSize = detailFontSize,
                    color = detailInk,
                    textAlign = textAlign,
                    modifier = flightAnchor(
                        "teacher",
                        course.teacher.trim(),
                        detailFontSize,
                        FontWeight.Normal,
                        detailInk,
                    ),
                )
            }
            if (style.showLocation && course.location.isNotBlank()) {
                hasAnyField = true
                CardDetailLine(
                    text = course.location.trim(),
                    fontSize = detailFontSize,
                    color = detailInk,
                    textAlign = textAlign,
                    modifier = flightAnchor(
                        "location",
                        course.location.trim(),
                        detailFontSize,
                        FontWeight.Normal,
                        detailInk,
                    ),
                )
            }
            if (style.showTime) {
                hasAnyField = true
                val startLabel = if (style.showTimeLabels) {
                    TimetableStrings.formatClassStartsAt(course.startTime)
                } else {
                    course.startTime
                }
                CardDetailLine(
                    text = startLabel,
                    fontSize = detailFontSize,
                    color = detailInk,
                    textAlign = textAlign,
                    modifier = flightAnchor(
                        "time",
                        startLabel,
                        detailFontSize,
                        FontWeight.Normal,
                        detailInk,
                    ),
                )
                val endLabel = if (style.showTimeLabels) {
                    TimetableStrings.formatClassEndsAt(course.endTime)
                } else {
                    course.endTime
                }
                CardDetailLine(
                    text = endLabel,
                    fontSize = detailFontSize,
                    color = detailInk,
                    textAlign = textAlign,
                    modifier = flightAnchor(
                        "timeEnd",
                        endLabel,
                        detailFontSize,
                        FontWeight.Normal,
                        detailInk,
                    ),
                )
            }
            if (style.showWeeks) {
                hasAnyField = true
                val weeksLabel = TimetableStrings.formatCourseWeekDescription(course)
                CardDetailLine(
                    text = weeksLabel,
                    fontSize = detailFontSize,
                    color = detailInk,
                    textAlign = textAlign,
                    modifier = flightAnchor(
                        "weeks",
                        weeksLabel,
                        detailFontSize,
                        FontWeight.Normal,
                        detailInk,
                    ),
                )
            }
            if (style.showDescription && !course.description.isNullOrBlank()) {
                hasAnyField = true
                val descriptionLabel = course.description!!.trim()
                CardDetailLine(
                    text = descriptionLabel,
                    fontSize = detailFontSize,
                    color = detailInk,
                    textAlign = textAlign,
                    maxLines = 2,
                    modifier = flightAnchor(
                        "description",
                        descriptionLabel,
                        detailFontSize,
                        FontWeight.Normal,
                        detailInk,
                        maxLines = 2,
                    ),
                )
            }
            // ── 天气一行（Dart `weather:` → `CourseWeatherDisplay`；受
            //    `weatherShowOnWeekCard` 与现象/温度/概率三开关控制）──
            val weatherText = model.weatherText
            if (weatherText != null) {
                hasAnyField = true
                CardDetailLine(
                    text = weatherText,
                    fontSize = detailFontSize,
                    color = detailInk,
                    textAlign = textAlign,
                    modifier = flightAnchor(
                        "weather",
                        weatherText,
                        detailFontSize,
                        FontWeight.Normal,
                        detailInk,
                    ),
                )
            }
            // Dart 的兜底：七个字段全关也必须有课名，否则卡上只剩留白。
            if (!hasAnyField) {
                Text(
                    text = course.name,
                    style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.BOLD),
                    fontSize = titleFontSize.sp,
                    color = ink,
                    textAlign = textAlign,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    modifier = flightAnchor(
                        "name",
                        course.name,
                        titleFontSize,
                        FontWeight.Bold,
                        ink,
                    ),
                )
            }
        }

        // ── 右上角角标：铃铛 / 假 / 停 / 冲突 **一行多枚**（Dart `course_card.dart:_buildBadgeRow`，
        //    `:610-661`：提醒铃铛排在最前，其后 showHoliday / showSuspended / customBadgeText）──
        // 一审漏了两件事：①假期角标从来没画（`holidayForDay` 是死参数）；②停课只有压淡、
        // 没有「停」字。这里按 Dart 的顺序与优先级补齐：假期优先于停课
        //（`showSuspended: isSuspended && !isHoliday`，`:461`）。
        // 铃铛**只在真实设过提醒时亮**（`WeekCardModel.hasReminder` ← `classReminders`）；
        // 没有这份数据（开学日未设 / 宿主没传键集）就什么都不画，不做假的已设标记。
        val badges = buildList {
            // 情侣课的「TA的课」角标（B1 第二阶段）：与日视图同一枚文案
            //（`DayViewStrings.coupleTimetableLegendPartner`），不新增 ARB 键。
            if (model.isPartnerCourse) add(DayViewStrings.coupleTimetableLegendPartner.text)
            if (isHoliday) add(TimetableStrings.holidayBadgeLabel.text)
            if (model.isSuspended && !isHoliday) add(TimetableStrings.suspendedBadgeLabel.text)
            if (model.badge == WeekCardBadge.CONFLICT) add(TimetableStrings.conflictLabel.text)
        }
        if (model.hasReminder || badges.isNotEmpty()) {
            Row(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(top = 2.dp, end = 2.dp),
                horizontalArrangement = Arrangement.spacedBy(2.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                // 提醒铃铛（Dart `_buildReminderIndicator`）：16dp 白底圆 + 主题蓝图标，
                // 与作业红点同尺寸、同「白底 + 圆」口径，只靠图标区分语义。
                if (model.hasReminder) {
                    Box(
                        modifier = Modifier
                            .size(16.dp)
                            .clip(CircleShape)
                            .background(Color.White.copy(alpha = 0.92f)),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            imageVector = MiuixIcons.Alarm,
                            contentDescription = null,
                            modifier = Modifier.size(10.dp),
                            tint = MiuixTheme.colorScheme.primary,
                        )
                    }
                }
                badges.forEach { label ->
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(999.dp))
                            .background(ink.copy(alpha = 0.22f))
                            .padding(horizontal = 3.dp, vertical = 1.dp),
                    ) {
                        Text(
                            text = label,
                            style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.BOLD),
                            fontSize = overlineFontSize.sp,
                            color = ink,
                            maxLines = 1,
                        )
                    }
                }
            }
        }

        // ── 左上角「本周有作业」小红点（Dart `showHomeworkIndicator`，
        //    `course_card.dart:443-449` 的 `_buildHomeworkIndicator(size: 15, iconSize: 9)`）──
        if (model.hasHomework) {
            Box(
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .padding(top = 4.dp, start = 4.dp)
                    .size(15.dp)
                    .clip(CircleShape)
                    .background(Color.White.copy(alpha = 0.95f)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = MiuixIcons.Tasks,
                    contentDescription = TimetableStrings.courseTaskAction.text,
                    modifier = Modifier.size(9.dp),
                    tint = Color(QingyuTheme.destructive()),
                )
            }
        }
    }
}

/** 课卡的一行详情（Dart `_buildCompactTextLines` 的详情行）。 */
@Composable
private fun CardDetailLine(
    text: String,
    fontSize: Float,
    color: Color,
    textAlign: TextAlign,
    maxLines: Int = 1,
    modifier: Modifier = Modifier,
) {
    Spacer(modifier = Modifier.height(WeekCardMetrics.LINE_GAP_DP.dp))
    Text(
        text = text,
        style = MiuixTheme.textStyles.footnote2,
        fontSize = fontSize.sp,
        color = color,
        textAlign = textAlign,
        maxLines = maxLines,
        overflow = TextOverflow.Ellipsis,
        modifier = modifier,
    )
}

/** `#RRGGBB` / `RRGGBB` → ARGB int；解析不出返回 null（交给对比度守卫回落自动墨）。 */
private fun parseArgbOrNull(hex: String?): Int? {
    val text = hex?.trim().orEmpty()
    if (text.isEmpty()) return null
    return runCatching {
        android.graphics.Color.parseColor(if (text.startsWith("#")) text else "#$text")
    }.getOrNull()
}
