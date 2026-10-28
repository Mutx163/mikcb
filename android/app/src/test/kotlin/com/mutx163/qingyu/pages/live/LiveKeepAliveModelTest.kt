package com.mutx163.qingyu.pages.live

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「后台保活」子屏模型层单测（P3-J 补口 A3）。
 *
 * 期望值全部**手推**（照 Dart `_LiveKeepAliveSettingsScreenState` 与
 * `_LiveKeepAliveServiceTile` 的判据一条条推出来），不从实现里抄。
 *
 * 覆盖：
 * 1. 权限三态判定（含「没探测过 = UNKNOWN，不许猜」这条）；
 * 2. 服务行可用性判定（按钮显隐、整行可点与否）；
 * 3. 确认弹窗放行判据（null / false 都不放行）；
 * 4. 刷新计划与探测折叠（3 次 × 450ms、读到 true 即停、序列短于预算时收口）；
 * 5. 状态变异纯函数与「未知态用中性色」的色调映射。
 */
class LiveKeepAliveModelTest {

    // ── 1. 权限三态 ──

    @Test
    fun `没探测过一律 UNKNOWN 不猜`() {
        // 读不到状态时不能报「未开启」——否则权限其实已授予时会摆一条橙色警示吓人。
        assertEquals(
            LivePermissionStatus.UNKNOWN,
            LiveKeepAliveModel.resolvePermissionStatus(checked = false, granted = false),
        )
        // 没探测过时 granted 无意义，仍是 UNKNOWN。
        assertEquals(
            LivePermissionStatus.UNKNOWN,
            LiveKeepAliveModel.resolvePermissionStatus(checked = false, granted = true),
        )
    }

    @Test
    fun `探测过才按 granted 分绿橙`() {
        assertEquals(
            LivePermissionStatus.GRANTED,
            LiveKeepAliveModel.resolvePermissionStatus(checked = true, granted = true),
        )
        assertEquals(
            LivePermissionStatus.DENIED,
            LiveKeepAliveModel.resolvePermissionStatus(checked = true, granted = false),
        )
    }

    @Test
    fun `色调映射 未知中性 已授予正向 未授予警示`() {
        assertEquals(LiveStatusTone.NEUTRAL, LiveKeepAliveModel.resolveTone(LivePermissionStatus.UNKNOWN))
        assertEquals(LiveStatusTone.POSITIVE, LiveKeepAliveModel.resolveTone(LivePermissionStatus.GRANTED))
        assertEquals(LiveStatusTone.CAUTION, LiveKeepAliveModel.resolveTone(LivePermissionStatus.DENIED))
    }

    @Test
    fun `服务行色调只按是否已开启分绿橙`() {
        // Dart `_LiveKeepAliveServiceTile`：enabled ? green : orange，没有未知态。
        assertEquals(LiveStatusTone.POSITIVE, LiveKeepAliveModel.resolveServiceTone(true))
        assertEquals(LiveStatusTone.CAUTION, LiveKeepAliveModel.resolveServiceTone(false))
    }

    // ── 2. 服务行可用性 ──

    @Test
    fun `未开启才出「去开启」按钮 已开启隐藏`() {
        assertTrue(LiveKeepAliveModel.shouldShowEnableButton(accessibilityEnabled = false))
        assertFalse(LiveKeepAliveModel.shouldShowEnableButton(accessibilityEnabled = true))
    }

    @Test
    fun `已开启时整行不可点 未开启可点`() {
        // Dart `onTap: enabled ? null : onOpenSettings`：已开启再点会重复弹确认弹窗。
        assertTrue(LiveKeepAliveModel.isServiceRowClickable(accessibilityEnabled = false))
        assertFalse(LiveKeepAliveModel.isServiceRowClickable(accessibilityEnabled = true))
    }

    // ── 3. 确认弹窗放行 ──

    @Test
    fun `确认弹窗只有 true 放行 null 与 false 都不放行`() {
        // Dart `if (confirmed != true) return;`：点外部 / 返回键关掉返回 null。
        assertFalse(LiveKeepAliveModel.shouldProceedToSettings(null))
        assertFalse(LiveKeepAliveModel.shouldProceedToSettings(false))
        assertTrue(LiveKeepAliveModel.shouldProceedToSettings(true))
    }

    // ── 4. 刷新计划与探测折叠 ──

    @Test
    fun `首读已开启时不补探测`() {
        val plan = LiveKeepAliveModel.buildRefreshPlan(accessibilityEnabled = true, retryIfDisabled = true)
        assertEquals(1, plan.initialProbeCount)
        assertEquals(0, plan.retryAttempts)
        assertEquals(450L, plan.retryDelayMillis)
    }

    @Test
    fun `首读未开启且要求重试时补 3 次 每次 450 毫秒`() {
        val plan = LiveKeepAliveModel.buildRefreshPlan(accessibilityEnabled = false, retryIfDisabled = true)
        assertEquals(1, plan.initialProbeCount)
        assertEquals(3, plan.retryAttempts)
        assertEquals(450L, plan.retryDelayMillis)
    }

    @Test
    fun `未要求重试时不补探测`() {
        val plan = LiveKeepAliveModel.buildRefreshPlan(accessibilityEnabled = false, retryIfDisabled = false)
        assertEquals(0, plan.retryAttempts)
        assertEquals(450L, plan.retryDelayMillis)
    }

    @Test
    fun `首读就开启时只消耗一次探测`() {
        val outcome = LiveKeepAliveModel.resolveRefreshOutcome(listOf(true), retryIfDisabled = true)
        assertTrue(outcome.enabled)
        assertEquals(1, outcome.probesUsed)
    }

    @Test
    fun `重试第一次读到开启就停`() {
        val outcome = LiveKeepAliveModel.resolveRefreshOutcome(listOf(false, true), retryIfDisabled = true)
        assertTrue(outcome.enabled)
        assertEquals(2, outcome.probesUsed)
    }

    @Test
    fun `重试预算用满后读到开启也算成功`() {
        // 首读 + 3 次重试 = 最多 4 次探测；第 4 次读到 true。
        val outcome = LiveKeepAliveModel.resolveRefreshOutcome(
            listOf(false, false, false, true),
            retryIfDisabled = true,
        )
        assertTrue(outcome.enabled)
        assertEquals(4, outcome.probesUsed)
    }

    @Test
    fun `重试预算用尽仍未开启判未开启`() {
        val outcome = LiveKeepAliveModel.resolveRefreshOutcome(
            listOf(false, false, false, false),
            retryIfDisabled = true,
        )
        assertFalse(outcome.enabled)
        assertEquals(4, outcome.probesUsed)
    }

    @Test
    fun `探测序列短于预算时按实际次数收口`() {
        val outcome = LiveKeepAliveModel.resolveRefreshOutcome(listOf(false, false), retryIfDisabled = true)
        assertFalse(outcome.enabled)
        assertEquals(2, outcome.probesUsed)
    }

    @Test
    fun `没有探测结果时不猜开启`() {
        val outcome = LiveKeepAliveModel.resolveRefreshOutcome(emptyList(), retryIfDisabled = true)
        assertFalse(outcome.enabled)
        assertEquals(0, outcome.probesUsed)
    }

    @Test
    fun `不要求重试时只看首读`() {
        // 后面即使有 true 也不采纳：Dart 不重试就只读一次。
        val outcome = LiveKeepAliveModel.resolveRefreshOutcome(listOf(false, true), retryIfDisabled = false)
        assertFalse(outcome.enabled)
        assertEquals(1, outcome.probesUsed)
    }

    // ── 5. 状态变异与可选行 ──

    @Test
    fun `翻转隐藏开关`() {
        val initial = LiveKeepAliveState(hideFromRecents = false)
        assertTrue(initial.withToggledHideFromRecents().hideFromRecents)
        assertFalse(initial.withToggledHideFromRecents().withToggledHideFromRecents().hideFromRecents)
    }

    @Test
    fun `探测回填同时写上已探测标记`() {
        val probed = LiveKeepAliveState().withAccessibilityProbe(enabled = true)
        assertTrue(probed.accessibilityEnabled)
        assertTrue(probed.accessibilityChecked)
        assertEquals(
            LivePermissionStatus.GRANTED,
            LiveKeepAliveModel.resolvePermissionStatus(
                checked = probed.accessibilityChecked,
                granted = probed.accessibilityEnabled,
            ),
        )
    }

    @Test
    fun `勿扰探测回填同时写上已探测标记`() {
        val probed = LiveKeepAliveState().withDoNotDisturbProbe(granted = false)
        assertFalse(probed.doNotDisturbAccessGranted)
        assertTrue(probed.doNotDisturbAccessChecked)
        assertEquals(
            LivePermissionStatus.DENIED,
            LiveKeepAliveModel.resolveDoNotDisturbStatus(
                checked = probed.doNotDisturbAccessChecked,
                granted = probed.doNotDisturbAccessGranted,
            ),
        )
    }

    @Test
    fun `未探测过的勿扰权限是 UNKNOWN`() {
        val fresh = LiveKeepAliveState()
        assertEquals(
            LivePermissionStatus.UNKNOWN,
            LiveKeepAliveModel.resolveDoNotDisturbStatus(
                checked = fresh.doNotDisturbAccessChecked,
                granted = fresh.doNotDisturbAccessGranted,
            ),
        )
    }

    @Test
    fun `默认状态全部关闭且未探测`() {
        val fresh = LiveKeepAliveState()
        assertFalse(fresh.hideFromRecents)
        assertFalse(fresh.accessibilityEnabled)
        assertFalse(fresh.accessibilityChecked)
        assertFalse(fresh.doNotDisturbAccessGranted)
        assertFalse(fresh.doNotDisturbAccessChecked)
    }
}
