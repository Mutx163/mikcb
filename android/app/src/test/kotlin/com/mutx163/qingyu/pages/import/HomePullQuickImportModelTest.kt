package com.mutx163.qingyu.pages.import

import java.time.Duration
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 首页下拉快捷导入测试（P3-G1 · home_pull_quick_import.dart）。
 *
 * Dart 源是挂 Overlay 的异步流程（闭包 + Timer）；能脱离 Android 抽成纯逻辑的
 * 有四块，期望值全部按 Dart 源手推：
 * 1. 整场 / 写入两级看门狗的选取（未进写入挂整场 120s，进入写入换写入 5min）；
 * 2. 收尾幂等 + 取消规则（写入开始后不能「假装取消成功」）；
 * 3. prepare 前置失败的文案序与 silent 抑制；
 * 4. 喂给仓库网页登录页的派生参数（标题 / 描述 / 校名首字 / 资源目录 / JS 路径回退）。
 */
class HomePullQuickImportModelTest {

    // ==========================================
    // 1. 看门狗常量与选取
    // ==========================================

    @Test
    fun `整场与写入看门狗时长与 Dart 常量一致`() {
        // Dart: _kHomePullQuickImportSessionTimeout = Duration(seconds: 120)
        assertEquals(Duration.ofSeconds(120), HomePullQuickImportModel.SESSION_TIMEOUT)
        // Dart: _kHomePullQuickImportWriteTimeout = Duration(minutes: 5)
        assertEquals(Duration.ofMinutes(5), HomePullQuickImportModel.WRITE_TIMEOUT)
    }

    @Test
    fun `看门狗选取 未进写入用整场 进入写入后换写入 收尾后不再挂`() {
        // Dart armSessionWatchdog: importWriteStarted 未置位 → Timer(sessionTimeout)
        assertEquals(
            HomePullQuickImportWatchdog.SESSION,
            HomePullQuickImportModel.armWatchdog(HomePullQuickImportSession()),
        )
        // importWriteStarted 置位 → 换 Timer(writeTimeout)，整场看门狗被取消
        assertEquals(
            HomePullQuickImportWatchdog.WRITE,
            HomePullQuickImportModel.armWatchdog(HomePullQuickImportSession(writeStarted = true)),
        )
        // sessionFinished → 两个看门狗都不再挂
        assertEquals(
            HomePullQuickImportWatchdog.NONE,
            HomePullQuickImportModel.armWatchdog(HomePullQuickImportSession(finished = true)),
        )
    }

    // ==========================================
    // 2. 收尾幂等与取消规则
    // ==========================================

    @Test
    fun `completeSession 幂等 首次收尾定成败`() {
        // Dart completeSession: sessionFinished 已置位直接 return，先到先得
        val (first, justFinished) = HomePullQuickImportModel.completeSession(HomePullQuickImportSession(), success = true)
        assertTrue(justFinished)
        assertTrue(first.finished)
        assertTrue(first.success)

        val (second, secondJustFinished) = HomePullQuickImportModel.completeSession(first, success = false)
        assertFalse(secondJustFinished)
        // 后到的结果不改写先前的成败
        assertTrue(second.success)
    }

    @Test
    fun `写入开始前的取消当场收尾`() {
        // Dart requestCancel: 未进写入 → cancelRequested = true; completeSession(false); return true
        val step = HomePullQuickImportModel.requestCancel(HomePullQuickImportSession())
        assertTrue(step.accepted)
        assertTrue(step.justFinished)
        assertTrue(step.session.finished)
        assertFalse(step.session.success)
        assertTrue(step.session.cancelRequested)
    }

    @Test
    fun `写入阶段不能假装取消成功`() {
        // Dart requestCancel: 已进写入 → 只标记 cancelRequested，return false 等真实结果
        val session = HomePullQuickImportSession(writeStarted = true)
        val step = HomePullQuickImportModel.requestCancel(session)
        assertFalse(step.accepted)
        assertFalse(step.justFinished)
        assertFalse(step.session.finished)
        assertTrue(step.session.cancelRequested)
    }

    @Test
    fun `已结束的会话取消直接返回 true 且不再改动状态`() {
        // Dart requestCancel 首行: sessionFinished → return true
        val finished = HomePullQuickImportSession(finished = true, success = true)
        val step = HomePullQuickImportModel.requestCancel(finished)
        assertTrue(step.accepted)
        assertFalse(step.justFinished)
        // success 不被取消动作改写
        assertTrue(step.session.success)
    }

    @Test
    fun `后台导入开始只生效一次且收尾后忽略`() {
        // Dart onBackgroundImportStarted: importWriteStarted || sessionFinished → return
        val started = HomePullQuickImportModel.onBackgroundImportStarted(HomePullQuickImportSession())
        assertTrue(started.writeStarted)
        // 重复回调不再变化
        assertEquals(started, HomePullQuickImportModel.onBackgroundImportStarted(started))
        // 收尾后忽略
        val finished = HomePullQuickImportSession(finished = true)
        assertEquals(finished, HomePullQuickImportModel.onBackgroundImportStarted(finished))
    }

    @Test
    fun `看门狗到点按失败收尾并要求手动操作`() {
        // Dart watchdog fire: cancelRequested = true; completeSession(false); onNeedsManualAction()
        val step = HomePullQuickImportModel.onWatchdogExpired(HomePullQuickImportSession(writeStarted = true))
        assertTrue(step.justFinished)
        assertTrue(step.needsManualAction)
        assertTrue(step.session.finished)
        assertFalse(step.session.success)
        assertTrue(step.session.cancelRequested)

        // 已收尾的会话看门狗到点不重复触发（Dart 首行 if (sessionFinished) return）
        val again = HomePullQuickImportModel.onWatchdogExpired(step.session)
        assertFalse(again.justFinished)
        assertFalse(again.needsManualAction)
    }

    // ==========================================
    // 3. prepare 前置失败的文案序
    // ==========================================

    @Test
    fun `prepare 前置失败按 Dart 检查顺序取第一条`() {
        // allEntries.isEmpty → 暂无已保存的快捷导入记录
        assertEquals(
            HomePullQuickImportPrepareFailure.NO_SAVED_RECORDS,
            HomePullQuickImportModel.firstPrepareFailure(
                hasSavedMacroEntries = false,
                macroRecordAvailable = true,
                initialImportUrl = "https://example.com",
                overlayHostAvailable = true,
            ),
        )
        // 有条目但逐个取宏都为 null → 同一句
        assertEquals(
            HomePullQuickImportPrepareFailure.NO_SAVED_RECORDS,
            HomePullQuickImportModel.firstPrepareFailure(
                hasSavedMacroEntries = true,
                macroRecordAvailable = false,
                initialImportUrl = "https://example.com",
                overlayHostAvailable = true,
            ),
        )
        // 宏在但登录地址解析为 null → 未找到有效的教务登录地址
        assertEquals(
            HomePullQuickImportPrepareFailure.NO_VALID_LOGIN_URL,
            HomePullQuickImportModel.firstPrepareFailure(
                hasSavedMacroEntries = true,
                macroRecordAvailable = true,
                initialImportUrl = null,
                overlayHostAvailable = true,
            ),
        )
        // 地址有了但取不到 Overlay → 发生未知错误
        assertEquals(
            HomePullQuickImportPrepareFailure.UNKNOWN,
            HomePullQuickImportModel.firstPrepareFailure(
                hasSavedMacroEntries = true,
                macroRecordAvailable = true,
                initialImportUrl = "https://example.com",
                overlayHostAvailable = false,
            ),
        )
        // 全部就绪 → 无失败，继续挂 Overlay
        assertNull(
            HomePullQuickImportModel.firstPrepareFailure(
                hasSavedMacroEntries = true,
                macroRecordAvailable = true,
                initialImportUrl = "https://example.com",
                overlayHostAvailable = true,
            ),
        )
    }

    @Test
    fun `silent 抑制前置提示 非 silent 给 ARB 原文`() {
        // Dart _explainUnlessSilent: silent → 整句跳过
        assertNull(HomePullQuickImportModel.explainPrepareFailure(HomePullQuickImportPrepareFailure.NO_SAVED_RECORDS, silent = true))

        assertEquals(
            "暂无已保存的快捷导入记录",
            HomePullQuickImportModel.explainPrepareFailure(HomePullQuickImportPrepareFailure.NO_SAVED_RECORDS, silent = false),
        )
        assertEquals(
            "未找到有效的教务登录地址",
            HomePullQuickImportModel.explainPrepareFailure(HomePullQuickImportPrepareFailure.NO_VALID_LOGIN_URL, silent = false),
        )
        assertEquals(
            "发生未知错误",
            HomePullQuickImportModel.explainPrepareFailure(HomePullQuickImportPrepareFailure.UNKNOWN, silent = false),
        )
    }

    // ==========================================
    // 4. 喂给网页登录页的派生参数
    // ==========================================

    @Test
    fun `标题与描述按 ARB 模板插值`() {
        // Dart: l10n.quickImportTitle(selectedMacro.schoolName)
        assertEquals("快捷导入 - 清华大学", HomePullQuickImportModel.quickImportTitle("清华大学"))
        // Dart: l10n.courseImportQuickImportDescription(schoolName, adapterName)
        assertEquals(
            "快捷导入 北京大学 教务系统",
            HomePullQuickImportModel.quickImportDescription(schoolName = "北京大学", adapterName = "教务系统"),
        )
    }

    @Test
    fun `校名首字取首字符 空名回井号`() {
        // Dart: schoolName.isNotEmpty ? schoolName[0] : '#'
        assertEquals("清", HomePullQuickImportModel.schoolInitial("清华大学"))
        assertEquals("#", HomePullQuickImportModel.schoolInitial(""))
    }

    @Test
    fun `资源目录与 JS 路径空值回退`() {
        // Dart: schoolResourceFolder.isNotEmpty ? schoolResourceFolder : schoolId
        assertEquals("school-1", HomePullQuickImportModel.resolveSchoolResourceFolder("", "school-1"))
        assertEquals("folder-x", HomePullQuickImportModel.resolveSchoolResourceFolder("folder-x", "school-1"))
        // Dart: adapterAssetJsPath.isNotEmpty ? adapterAssetJsPath : 'macro/${adapterId}.js'
        assertEquals("macro/adp1.js", HomePullQuickImportModel.resolveAdapterAssetJsPath("", "adp1"))
        assertEquals("custom/a.js", HomePullQuickImportModel.resolveAdapterAssetJsPath("custom/a.js", "adp1"))
        // 适配器入口的固定身份字段
        assertEquals("macro", HomePullQuickImportModel.ADAPTER_CATEGORY_MACRO)
        assertEquals("macro", HomePullQuickImportModel.ADAPTER_MAINTAINER_MACRO)
    }

    @Test
    fun `导入地址解析走仓库同源规则`() {
        // Dart prepare(): resolveWarehouseImportUrl(customImportUrl, macro.importUrl)
        assertEquals(
            "https://custom.example.com",
            HomePullQuickImportModel.resolveInitialImportUrl("https://custom.example.com", "https://default.example.com"),
        )
        // 自定义地址为空 → 默认地址
        assertEquals(
            "https://default.example.com",
            HomePullQuickImportModel.resolveInitialImportUrl("", "https://default.example.com"),
        )
        // 两个都没有 → null（触发「未找到有效的教务登录地址」）
        assertNull(HomePullQuickImportModel.resolveInitialImportUrl("", ""))
    }
}
