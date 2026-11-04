package com.mutx163.qingyu.pages.timetable.day

import com.mutx163.qingyu.core.CourseCardSurface
import com.mutx163.qingyu.core.HomeMaterialRenderSpec
import com.mutx163.qingyu.core.SurfaceMaterialState
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 日视图卡面档位（[dayAgendaSurfaceAlpha]）的落定口径。
 *
 * 为什么单独测：这张表决定「卡色压多少在壁纸上」。写错时编译不报错、界面也只是
 * 「好像有点透」，只有真机上盯着看才发现 —— 而这一档是**跟周网格课卡对齐**用的，
 * 两边漂了就是同一天在两个视图里材质不一样。这里把四个分支逐一钉住。
 *
 * 输入用最小实现 [CourseCardSurface]（而不是 `pages/settings` 的
 * `HomeMaterialRenderSpec`）：本表只吃「档位 + 染色系数」，不该为了造一个测试输入
 * 把设置页模型拖进 timetable 的 L0 编译闭包。
 */
class DayAgendaSurfaceLogicTest {

    private fun spec(
        state: SurfaceMaterialState,
        tintAlpha: Float = 0.70f,
    ): CourseCardSurface = object : CourseCardSurface {
        override val courseCard: SurfaceMaterialState = state
        override val courseCardTintAlpha: Float = tintAlpha
    }

    @Test
    fun `没有材质快照时保持原来的实体透明度`() {
        assertEquals(1f, dayAgendaSurfaceAlpha(null, 1f), 0.0001f)
        assertEquals(0.95f, dayAgendaSurfaceAlpha(null, 0.95f), 0.0001f)
    }

    @Test
    fun `实体档不动卡面`() {
        for (state in listOf(
            SurfaceMaterialState.SOLID,
            SurfaceMaterialState.OFF,
            SurfaceMaterialState.FROST_PROGRESSIVE,
        )) {
            assertEquals(
                "档位 $state 应保持实体",
                0.62f,
                dayAgendaSurfaceAlpha(spec(state), 0.62f),
                0.0001f,
            )
        }
    }

    @Test
    fun `高斯档压到五五开`() {
        // 与周网格课卡同值（`CourseGridCard` 的 0.55）：没有预糊管线时的降级观感。
        assertEquals(
            0.55f,
            dayAgendaSurfaceAlpha(spec(SurfaceMaterialState.FROST_GAUSSIAN), 1f),
            0.0001f,
        )
        assertEquals(
            0.55f,
            dayAgendaSurfaceAlpha(spec(SurfaceMaterialState.FROST), 1f),
            0.0001f,
        )
        // 与卡片自己的压淡相乘（停课 0.84 / 非本周 0.62）。
        assertEquals(
            0.55f * 0.84f,
            dayAgendaSurfaceAlpha(spec(SurfaceMaterialState.FROST_GAUSSIAN), 0.84f),
            0.0001f,
        )
    }

    @Test
    fun `液态档吃卡片自己的染色旋钮`() {
        assertEquals(
            0.42f,
            dayAgendaSurfaceAlpha(
                spec(SurfaceMaterialState.LIQUID_GLASS, tintAlpha = 0.42f),
                1f,
            ),
            0.0001f,
        )
        assertEquals(
            0.42f * 0.95f,
            dayAgendaSurfaceAlpha(
                spec(SurfaceMaterialState.LIQUID_GLASS, tintAlpha = 0.42f),
                0.95f,
            ),
            0.0001f,
        )
    }

    @Test
    fun `染色旋钮越界时夹回可用区间`() {
        // 0 会让卡面完全消失（只剩模糊背景，课色一点不剩）；>1 会盖死壁纸。
        assertEquals(
            0.08f,
            dayAgendaSurfaceAlpha(
                spec(SurfaceMaterialState.LIQUID_GLASS, tintAlpha = 0f),
                1f,
            ),
            0.0001f,
        )
        assertEquals(
            1f,
            dayAgendaSurfaceAlpha(
                spec(SurfaceMaterialState.LIQUID_GLASS, tintAlpha = 3f),
                1f,
            ),
            0.0001f,
        )
    }
}
