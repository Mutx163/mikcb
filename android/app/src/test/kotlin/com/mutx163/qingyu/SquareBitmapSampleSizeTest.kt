package com.mutx163.qingyu

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 超级岛大图标/方图缩略的采样比（2026-10-02 审查）。
 *
 * `decodeSquareBitmap` 原先是裸 `BitmapFactory.decodeFile(path)`：
 * 为了贴一张 dp(56)（约 96-168px）的通知大图标，
 * 会先把用户相册里 4032×3024 的原件整张解进内存（ARGB_8888 约 47MB），
 * 而 `computeNextTickDelayMillis` 在课前与课末的一分钟里返回 1000L，
 * 每次 tick 都重建通知（LiveUpdateService.kt:2135）—— 主线程每秒一次全尺寸解码。
 * 解码失败时 BitmapFactory 不抛异常只返回 null，表现就是图标静默消失。
 */
class SquareBitmapSampleSizeTest {
    @Test
    fun picksLargestPowerOfTwoKeepingTargetSide() {
        // 短边 3000：3000/16=187 ≥ 96，3000/32=93 < 96 → 16
        assertEquals(16, computeSquareBitmapSampleSize(4000, 3000, 96))
        // 按短边算：长边会被裁掉
        assertEquals(16, computeSquareBitmapSampleSize(3000, 4000, 96))
        assertEquals(2, computeSquareBitmapSampleSize(400, 300, 96))
    }

    @Test
    fun doesNotSampleAlreadySmallImages() {
        assertEquals(1, computeSquareBitmapSampleSize(80, 60, 96))
        assertEquals(1, computeSquareBitmapSampleSize(96, 96, 96))
        assertEquals(1, computeSquareBitmapSampleSize(120, 96, 96))
    }

    @Test
    fun invalidInputsFallBackToNoSampling() {
        assertEquals(1, computeSquareBitmapSampleSize(0, 100, 96))
        assertEquals(1, computeSquareBitmapSampleSize(100, -1, 96))
        assertEquals(1, computeSquareBitmapSampleSize(100, 100, 0))
    }

    @Test
    fun sampledSideNeverFallsBelowTarget() {
        val targets = listOf(96, 112, 168, 256)
        val sides = listOf(200, 500, 1024, 3000, 4032, 8192)
        for (target in targets) {
            for (side in sides) {
                val sample = computeSquareBitmapSampleSize(side * 4 / 3, side, target)
                assertTrue(
                    "side=$side target=$target sample=$sample",
                    sample == 1 || side / sample >= target,
                )
                assertTrue(
                    "采样比必须是 2 的幂: $sample",
                    sample and (sample - 1) == 0,
                )
            }
        }
    }
}
