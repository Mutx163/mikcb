package com.mutx163.qingyu.pages.import

import com.mutx163.qingyu.pages.import.warehouse.resolveWarehouseImportUrl
import java.time.Duration

/**
 * 首页下拉快捷导入的**会话推进状态**（P3-G1 · 移植 `home_pull_quick_import.dart`）。
 *
 * Dart 侧是闭包里的四个可变标志（sessionFinished / completer 成败 / cancelRequested /
 * importWriteStarted）；这里收拢成不可变值对象，由 [HomePullQuickImportModel] 的
 * 纯函数推进——收尾幂等、取消规则这些判定才进得了 JVM 单测。
 *
 * 不含 Overlay / Timer / WebView：宿主挂载、看门狗计时、网页登录页由渲染与应用层驱动，
 * 本层只回答「此刻该挂哪个看门狗」「这次取消算不算数」「到点该怎么收尾」。
 */
data class HomePullQuickImportSession(
    /** 会话是否已收尾（Dart `sessionFinished`；首次 [HomePullQuickImportModel.completeSession] 后置位）。 */
    val finished: Boolean = false,
    /** 收尾时定下的成败（Dart `completer.complete(success)` 的落点；未收尾无意义）。 */
    val success: Boolean = false,
    /** 是否有人请求过取消（Dart `cancelRequested`；网页登录页轮询它来中止回放）。 */
    val cancelRequested: Boolean = false,
    /** 是否已进入实际写入阶段（Dart `importWriteStarted`；决定取消规则与看门狗选取）。 */
    val writeStarted: Boolean = false,
)

/** 一步推进后的落点：新状态 + 本步是否刚好完成收尾 + 是否该提示用户手动操作。 */
data class HomePullQuickImportStep(
    val session: HomePullQuickImportSession,
    /** 本步是否把会话从「进行中」推进到「已收尾」（幂等调用为 false）。 */
    val justFinished: Boolean = false,
    /** 本步是否要求用户去手动跑一遍（看门狗到点那条出口）。 */
    val needsManualAction: Boolean = false,
)

/** 取消请求的裁决：Dart `requestCancel()` 的返回值 + 状态落点。 */
data class HomePullQuickImportCancelStep(
    val session: HomePullQuickImportSession,
    /**
     * Dart `requestCancel()` 的返回语义：true = 「无需再等取消回执」——要么会话已结束
     * （无事可撤），要么还没进写入、当场按失败收尾；false = 已进写入，不能假装取消
     * 成功，只能标记 [HomePullQuickImportSession.cancelRequested] 等真实导入结果。
     */
    val accepted: Boolean,
    /** 当场收尾才为 true；已结束的会话再取消是 no-op（accepted = true 但 justFinished = false）。 */
    val justFinished: Boolean,
)

/** 此刻该挂的看门狗（同一时刻只挂一个：进写入后整场看门狗被取消、换挂写入看门狗）。 */
enum class HomePullQuickImportWatchdog {
    /** 整场看门狗（120s）：管读宏 → 挂隐形网页 → 回放脚本全链路。 */
    SESSION,

    /** 写入看门狗（5min）：写入开始后接管，管底层存储/Provider 失去响应的情况。 */
    WRITE,

    /** 会话已收尾，不挂任何看门狗。 */
    NONE,
}

/** prepare 阶段的前置失败（每档对应一句 ARB 提示；检查顺序即 Dart 源里的书写顺序）。 */
enum class HomePullQuickImportPrepareFailure(val tip: ImportArbText) {
    /** 没有任何已保存的宏条目，或有条目但逐个都取不出宏记录。 */
    NO_SAVED_RECORDS(ImportStrings.noSavedQuickImportRecords),

    /** 宏记录在，但自定义地址与默认地址都解析不出可用的登录地址。 */
    NO_VALID_LOGIN_URL(ImportStrings.noValidWarehouseLoginUrl),

    /** 取不到根 Overlay 等环境性失败——文案按 Dart 走「发生未知错误」。 */
    UNKNOWN(ImportStrings.quickImportUnknownError),
}

/**
 * 首页下拉快捷导入的纯逻辑真源（P3-G1 · 移植 `lib/screens/import/home_pull_quick_import.dart`）。
 *
 * ## 为什么必须有整场看门狗（值取 120s 的依据，照抄 Dart 注释）
 *
 * 整条链路（读宏 → 挂隐形网页 → 回放脚本 → 执行导入）每段都有自己的超时，但没有一段
 * 管得住**整场**；任何一条没报回来的路都会让首页那颗药丸一直转下去（2026-09-22 真机）。
 * 120s = 合法路径的最慢组合（页面就绪 20s + 单步轮询 15s + 执行导入 30s）之上再留一档
 * 余量。写入阶段换挂独立的 5min 写入看门狗——正常写入远快于此，超过它说明底层存储或
 * Provider Future 已经失去响应。
 */
object HomePullQuickImportModel {

    /** 整场看门狗时长（Dart `_kHomePullQuickImportSessionTimeout`）。 */
    val SESSION_TIMEOUT: Duration = Duration.ofSeconds(120)

    /** 写入看门狗时长（Dart `_kHomePullQuickImportWriteTimeout`）。 */
    val WRITE_TIMEOUT: Duration = Duration.ofMinutes(5)

    /** 快捷导入喂给网页登录页的适配器入口固定 category（Dart `category: 'macro'`）。 */
    const val ADAPTER_CATEGORY_MACRO = "macro"

    /** 适配器入口固定 maintainer（Dart `maintainer: 'macro'`）。 */
    const val ADAPTER_MAINTAINER_MACRO = "macro"

    // ------------------------------------------------------------------
    // 会话推进
    // ------------------------------------------------------------------

    /**
     * 收尾会话（Dart `completeSession`）：**幂等，先到先得**——首次调用的成败定案，
     * 之后的收尾（不管是网页回调、看门狗还是取消）都改写不了结果。
     */
    fun completeSession(
        session: HomePullQuickImportSession,
        success: Boolean,
    ): HomePullQuickImportStep {
        if (session.finished) {
            return HomePullQuickImportStep(session = session)
        }
        return HomePullQuickImportStep(
            session = session.copy(finished = true, success = success),
            justFinished = true,
        )
    }

    /**
     * 请求取消（Dart `requestCancel`）：
     * - 会话已结束 → 直接 true（无事可撤）；
     * - 未进写入 → 标记取消并当场按失败收尾，true；
     * - 已进写入 → 只标记取消、等导入回调报告真实结果，false。
     */
    fun requestCancel(session: HomePullQuickImportSession): HomePullQuickImportCancelStep {
        if (session.finished) {
            return HomePullQuickImportCancelStep(session = session, accepted = true, justFinished = false)
        }
        val marked = session.copy(cancelRequested = true)
        if (!session.writeStarted) {
            return HomePullQuickImportCancelStep(
                session = marked.copy(finished = true, success = false),
                accepted = true,
                justFinished = true,
            )
        }
        return HomePullQuickImportCancelStep(session = marked, accepted = false, justFinished = false)
    }

    /**
     * 网页登录页报告「实际写入开始」（Dart `onBackgroundImportStarted`）：
     * 只生效一次；会话已收尾后到达的回调一律忽略。
     */
    fun onBackgroundImportStarted(session: HomePullQuickImportSession): HomePullQuickImportSession {
        if (session.writeStarted || session.finished) {
            return session
        }
        return session.copy(writeStarted = true)
    }

    /** 此刻该挂的看门狗（Dart `armSessionWatchdog` 的选取逻辑）。 */
    fun armWatchdog(session: HomePullQuickImportSession): HomePullQuickImportWatchdog = when {
        session.finished -> HomePullQuickImportWatchdog.NONE
        session.writeStarted -> HomePullQuickImportWatchdog.WRITE
        else -> HomePullQuickImportWatchdog.SESSION
    }

    /**
     * 看门狗到点（Dart 两个 Timer 的回调体）：标记取消、按失败收尾，
     * 并走「需要手动操作」那条既有出口（摘 Overlay + 提示去手动跑一遍）。
     * 已收尾的会话不重复触发。
     */
    fun onWatchdogExpired(session: HomePullQuickImportSession): HomePullQuickImportStep {
        if (session.finished) {
            return HomePullQuickImportStep(session = session)
        }
        return HomePullQuickImportStep(
            session = session.copy(cancelRequested = true, finished = true, success = false),
            justFinished = true,
            needsManualAction = true,
        )
    }

    // ------------------------------------------------------------------
    // prepare 前置失败
    // ------------------------------------------------------------------

    /**
     * prepare 的第一处前置失败，null = 可以继续挂 Overlay。
     *
     * 检查顺序与 Dart `prepare()` 逐条对齐：
     * 宏条目列表为空 → 逐个取宏全为 null → 登录地址解析为 null → 取不到 Overlay。
     * 前两档共享同一句提示（「暂无已保存的快捷导入记录」）。
     */
    fun firstPrepareFailure(
        hasSavedMacroEntries: Boolean,
        macroRecordAvailable: Boolean,
        initialImportUrl: String?,
        overlayHostAvailable: Boolean,
    ): HomePullQuickImportPrepareFailure? = when {
        !hasSavedMacroEntries -> HomePullQuickImportPrepareFailure.NO_SAVED_RECORDS
        !macroRecordAvailable -> HomePullQuickImportPrepareFailure.NO_SAVED_RECORDS
        initialImportUrl == null -> HomePullQuickImportPrepareFailure.NO_VALID_LOGIN_URL
        !overlayHostAvailable -> HomePullQuickImportPrepareFailure.UNKNOWN
        else -> null
    }

    /**
     * 前置失败的解释句（Dart `_explainUnlessSilent`）：silent 时整句跳过——
     * 「课表自动更新」是用户没盯着的时候跑的，还没配好就弹提示纯属打扰。
     */
    fun explainPrepareFailure(
        failure: HomePullQuickImportPrepareFailure,
        silent: Boolean,
    ): String? = if (silent) null else failure.tip.zh

    // ------------------------------------------------------------------
    // 喂给网页登录页的派生参数
    // ------------------------------------------------------------------

    /** 隐形登录页标题（Dart `l10n.quickImportTitle(selectedMacro.schoolName)`）。 */
    fun quickImportTitle(schoolName: String): String =
        ImportStrings.quickImportTitle.filled("name", schoolName)

    /** 适配器入口描述（Dart `l10n.courseImportQuickImportDescription(schoolName, adapterName)`）。 */
    fun quickImportDescription(schoolName: String, adapterName: String): String =
        // 用 vararg 重载一次替换两个占位符：单参 `filled` 返回 String，
        // 链第二次时 receiver 已是 String、找不到 `filled`（2026-10-27 全队踩过）。
        ImportStrings.courseImportQuickImportDescription
            .filled("schoolName" to schoolName, "adapterName" to adapterName)

    /** 学校条目首字（Dart `schoolName[0]`，空名回 `#`）。 */
    fun schoolInitial(schoolName: String): String =
        schoolName.firstOrNull()?.toString() ?: "#"

    /** 学校资源目录回退（Dart：空则用 schoolId）。 */
    fun resolveSchoolResourceFolder(resourceFolder: String, schoolId: String): String =
        resourceFolder.ifEmpty { schoolId }

    /** 适配器注入脚本路径回退（Dart：空则 `macro/<adapterId>.js`）。 */
    fun resolveAdapterAssetJsPath(assetJsPath: String, adapterId: String): String =
        assetJsPath.ifEmpty { "macro/$adapterId.js" }

    /**
     * 教务导入地址解析（Dart `prepare()` 里的 `resolveWarehouseImportUrl`）。
     * 判定真源在仓库适配层（`pages/import/warehouse/`，P3-G2 落地），这里只做同源转发，
     * 保证「自定义地址优先、空/非法退默认、都不可用回 null」全应用只有一份实现。
     */
    fun resolveInitialImportUrl(customImportUrl: String?, defaultUrl: String): String? =
        resolveWarehouseImportUrl(customImportUrl, defaultUrl)
}
