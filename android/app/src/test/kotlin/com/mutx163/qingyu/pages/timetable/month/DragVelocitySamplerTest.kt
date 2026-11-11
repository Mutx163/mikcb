package com.mutx163.qingyu.pages.timetable.month

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.abs

/**
 * `DragVelocitySampler` 的判据测试。
 *
 * 背景（真机实测，2026-11-11）：旧实现用 `VelocityTracker` + **节点局部绝对坐标**
 * 采样，而这块拖拽区（面板 / 拉杆）自身在跟着日历高度上下移动，于是速度方向被
 * 面板位移抵消、常常反号 —— 25 次手势里 20 次反号，松手吸附把面板甩回原位，
 * 用户口径「上滑滑不上去、下拉拉不下来」。
 *
 * 这里锁三件事：
 * 1. 单位口径：匀速位移 → 速度 = 位移 ÷ 时长（不是位移本身，也不是像素/毫秒混用）；
 * 2. 方向：上滑得负数、下滑得正数（与 `MonthPanelModel.settleTarget` 的符号约定一致）；
 * 3. 抗噪：乱序样本丢掉、单样本/零时长返回 0、滑窗外的老位移不参与。
 */
class DragVelocitySamplerTest {

    @Test
    fun `匀速上滑_速度等于位移除时长且为负`() {
        val sampler = DragVelocitySampler()
        var time = 0L
        repeat(10) {
            sampler.add(time, -20f) // 每 10ms 上移 20px
            time += 10
        }
        // 9 个区间 × 20px = 180px，跨度 90ms ⇒ 2000px/s，方向向上（负）。
        assertEquals(-2000f, sampler.velocityPerSecond(), 1f)
    }

    @Test
    fun `匀速下滑_速度为正`() {
        val sampler = DragVelocitySampler()
        var time = 0L
        repeat(6) {
            sampler.add(time, 15f)
            time += 8
        }
        // 5 个区间 × 15px = 75px，跨度 40ms ⇒ 1875px/s。
        assertEquals(1875f, sampler.velocityPerSecond(), 1f)
    }

    @Test
    fun `单样本与零时长_返回零而不是无穷`() {
        val onlyOne = DragVelocitySampler()
        onlyOne.add(100L, -30f)
        assertEquals(0f, onlyOne.velocityPerSecond(), 0f)

        val sameClock = DragVelocitySampler()
        sameClock.add(100L, -30f)
        sameClock.add(100L, -30f)
        assertEquals(0f, sameClock.velocityPerSecond(), 0f)
    }

    @Test
    fun `时间倒退的样本被丢掉`() {
        val sampler = DragVelocitySampler()
        sampler.add(100L, -10f)
        sampler.add(90L, 999f) // 乱序：必须丢
        sampler.add(110L, -10f)
        // 只剩 100→110 这一段：−10px / 10ms ⇒ −1000px/s。
        assertEquals(-1000f, sampler.velocityPerSecond(), 1f)
    }

    @Test
    fun `滑窗外的老位移不参与`() {
        val sampler = DragVelocitySampler(windowMs = 80L)
        sampler.add(0L, 0f)
        sampler.add(10L, -400f) // 很早以前的一次大位移，必须被窗口丢掉
        var time = 100L
        repeat(11) {
            sampler.add(time, -1f) // 之后是缓慢匀速
            time += 10
        }
        // 200ms 时窗口只剩 120..200：8 个区间 × 1px / 80ms = 100px/s。
        val velocity = sampler.velocityPerSecond()
        assertTrue("老位移不该把速度拉大：$velocity", abs(velocity) < 200f)
        assertTrue("方向仍应为负：$velocity", velocity < 0f)
    }

    @Test
    fun `reset_之后重新计数`() {
        val sampler = DragVelocitySampler()
        sampler.add(0L, 0f)
        sampler.add(10L, -50f)
        assertEquals(-5000f, sampler.velocityPerSecond(), 1f)

        sampler.reset()
        assertEquals(0f, sampler.velocityPerSecond(), 0f)

        sampler.add(20L, 0f)
        sampler.add(30L, 25f)
        assertEquals(2500f, sampler.velocityPerSecond(), 1f)
    }
}
