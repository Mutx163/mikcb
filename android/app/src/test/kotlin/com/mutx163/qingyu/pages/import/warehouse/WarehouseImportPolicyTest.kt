package com.mutx163.qingyu.pages.import.warehouse

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 仓库导入判定策略单元测试。
 */
class WarehouseImportPolicyTest {

    @Test
    fun `shouldPromptRememberedLoginAutofill 必须同时满足六大前置条件`() {
        val remembered = WarehouseRememberedLogin(username = "202401", password = "secret_password")
        val candidate = WarehouseRememberedLogin(username = "", password = "")

        // 标称场景：有密码输入框、会话未激活、已记住密码、候选密码为空、未曾提示过、提示未在展示中 -> 应该提示
        assertTrue(
            shouldPromptRememberedLoginAutofill(
                hasPasswordField = true,
                rememberedLogin = remembered,
                candidate = candidate,
                hasPromptedAutofill = false,
                isPromptShowing = false,
                sessionActive = false,
            )
        )

        // 条件 1: 没有密码输入框 -> 不提示
        assertFalse(
            shouldPromptRememberedLoginAutofill(
                hasPasswordField = false,
                rememberedLogin = remembered,
                candidate = candidate,
                hasPromptedAutofill = false,
                isPromptShowing = false,
                sessionActive = false,
            )
        )

        // 条件 2: 会话已激活（探针确认在线） -> 登录框为假，抑制提示
        assertFalse(
            shouldPromptRememberedLoginAutofill(
                hasPasswordField = true,
                rememberedLogin = remembered,
                candidate = candidate,
                hasPromptedAutofill = false,
                isPromptShowing = false,
                sessionActive = true,
            )
        )

        // 条件 3: 候选已填有密码 -> 不提示覆盖
        assertFalse(
            shouldPromptRememberedLoginAutofill(
                hasPasswordField = true,
                rememberedLogin = remembered,
                candidate = WarehouseRememberedLogin("202401", "already_typed"),
                hasPromptedAutofill = false,
                isPromptShowing = false,
                sessionActive = false,
            )
        )

        // 条件 4: 已经提示过 -> 不重复打扰
        assertFalse(
            shouldPromptRememberedLoginAutofill(
                hasPasswordField = true,
                rememberedLogin = remembered,
                candidate = candidate,
                hasPromptedAutofill = true,
                isPromptShowing = false,
                sessionActive = false,
            )
        )

        // 条件 5: 弹窗正在展示中 -> 不重复弹
        assertFalse(
            shouldPromptRememberedLoginAutofill(
                hasPasswordField = true,
                rememberedLogin = remembered,
                candidate = candidate,
                hasPromptedAutofill = false,
                isPromptShowing = true,
                sessionActive = false,
            )
        )
    }

    @Test
    fun `shouldPromptRememberedLoginSave 保存凭据提示条件测试`() {
        // 未提示过且账号密码俱全，且此前未保存 -> 应该提示保存
        assertTrue(
            shouldPromptRememberedLoginSave(
                rememberedLogin = null,
                hasPromptedSave = false,
                isPromptShowing = false,
                candidateUsername = "student1",
                candidatePassword = "pass123",
            )
        )

        // 已保存完整密码 -> 不重复提示
        assertFalse(
            shouldPromptRememberedLoginSave(
                rememberedLogin = WarehouseRememberedLogin("student1", "pass123"),
                hasPromptedSave = false,
                isPromptShowing = false,
                candidateUsername = "student1",
                candidatePassword = "pass123",
            )
        )

        // 历史遗留残缺账号（密码为空） -> 允许提示补录新密码
        assertTrue(
            shouldPromptRememberedLoginSave(
                rememberedLogin = WarehouseRememberedLogin("student1", ""),
                hasPromptedSave = false,
                isPromptShowing = false,
                candidateUsername = "student1",
                candidatePassword = "new_pass",
            )
        )

        // 密码为空 -> 不提示
        assertFalse(
            shouldPromptRememberedLoginSave(
                rememberedLogin = null,
                hasPromptedSave = false,
                isPromptShowing = false,
                candidateUsername = "student1",
                candidatePassword = "",
            )
        )
    }

    @Test
    fun `sessionProbeMayStillSettle 探测等待判定`() {
        val config = WarehouseSessionProbeConfig(url = "https://jw.edu/probe")
        // 有配置且当前结论未知且网络探测在途中 -> 需要等待
        assertTrue(
            sessionProbeMayStillSettle(
                config = config,
                verdict = WarehouseSessionProbeVerdict.UNKNOWN,
                inFlight = true,
            )
        )

        // 结论已确定 -> 无需等待
        assertFalse(
            sessionProbeMayStillSettle(
                config = config,
                verdict = WarehouseSessionProbeVerdict.ACTIVE,
                inFlight = true,
            )
        )

        // 未配置探测（200+ 普通高校） -> 不等
        assertFalse(
            sessionProbeMayStillSettle(
                config = null,
                verdict = WarehouseSessionProbeVerdict.UNKNOWN,
                inFlight = true,
            )
        )
    }

    @Test
    fun `warehouseLoginCandidateAfterState 登录提交后的空口令回传不得冲掉候选`() {
        val submitted = WarehouseRememberedLogin(username = "202401", password = "secret_password")

        // 主路径：提交后跳课表页，新页面 collect() 回传「第一个文本框 + 空口令」⇒ 保留提交时的候选
        assertEquals(
            "已提交且未作答时，空口令回传不许冲掉候选（否则保存提示当场消失）",
            submitted,
            warehouseLoginCandidateAfterState(
                previous = submitted,
                incoming = WarehouseRememberedLogin(username = "搜索课程", password = ""),
                hasLoginAttempt = true,
                hasPromptedSave = false,
            ),
        )

        // 用户已作答「记住/不记住」⇒ 恢复跟随页面输入（下一次登录要能采集新值）
        assertEquals(
            "作答后必须恢复跟随页面输入",
            WarehouseRememberedLogin(username = "202402", password = ""),
            warehouseLoginCandidateAfterState(
                previous = submitted,
                incoming = WarehouseRememberedLogin(username = "202402", password = ""),
                hasLoginAttempt = true,
                hasPromptedSave = true,
            ),
        )

        // 新回传本身带口令（用户重输 / 站点回填）⇒ 以新值为准
        assertEquals(
            "带口令的新回传优先（用户重输后要存新值）",
            WarehouseRememberedLogin(username = "202401", password = "new_pass"),
            warehouseLoginCandidateAfterState(
                previous = submitted,
                incoming = WarehouseRememberedLogin(username = "202401", password = "new_pass"),
                hasLoginAttempt = true,
                hasPromptedSave = false,
            ),
        )

        // 还没提交：边输边采，空口令也要如实反映（不能把已清空的口令当仍有效）
        assertEquals(
            "未提交时不许钉住候选（边输边采要跟手）",
            WarehouseRememberedLogin(username = "202401", password = ""),
            warehouseLoginCandidateAfterState(
                previous = submitted,
                incoming = WarehouseRememberedLogin(username = "202401", password = ""),
                hasLoginAttempt = false,
                hasPromptedSave = false,
            ),
        )
    }

    @Test
    fun `shouldAutoRecordWarehouseImport 宏录制自动开启策略`() {
        // 强制录制 -> 恒开启
        assertTrue(shouldAutoRecordWarehouseImport(forceRecord = true, hasExistingMacro = true))
        assertTrue(shouldAutoRecordWarehouseImport(forceRecord = true, hasExistingMacro = false))

        // 普通导入：无宏时自动录制首条路径，已有宏时不录制
        assertTrue(shouldAutoRecordWarehouseImport(forceRecord = false, hasExistingMacro = false))
        assertFalse(shouldAutoRecordWarehouseImport(forceRecord = false, hasExistingMacro = true))
    }

    @Test
    fun `shouldDetachPlatformViewOnExit 页面反向退出与阈值判定`() {
        // 反向动画，且进度 <= 0.35 时摘除 WebView 平台视图
        assertTrue(shouldDetachPlatformViewOnExit(WarehouseAnimationStatus.REVERSE, 0.35))
        assertTrue(shouldDetachPlatformViewOnExit(WarehouseAnimationStatus.REVERSE, 0.10))

        // 反向动画但刚开始退出（0.50） -> 不摘
        assertFalse(shouldDetachPlatformViewOnExit(WarehouseAnimationStatus.REVERSE, 0.50))

        // 正向进入动画（FORWARD） -> 绝不摘除
        assertFalse(shouldDetachPlatformViewOnExit(WarehouseAnimationStatus.FORWARD, 0.20))
    }
}
