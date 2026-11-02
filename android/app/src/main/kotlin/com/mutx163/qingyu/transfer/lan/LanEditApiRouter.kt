package com.mutx163.qingyu.transfer.lan

import com.mutx163.qingyu.calendar.WeekExpressionParser
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.DartTime
import com.mutx163.qingyu.core.FormatException
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.share.LanEditSession
import com.mutx163.qingyu.share.TransferApplyMode
import java.time.Instant
import java.time.ZoneId
import java.util.Base64
import java.util.UUID

/**
 * 局域网编辑 API 的**数据与写入面**（对应 Dart `lib/services/lan_edit_host.dart` 的
 * `LanEditHost`）。
 *
 * 为什么要有这层接口：HTTP 那一层（[LanEditApiRouter] / [LanEditHttpServer]）不该知道
 * 课表存在哪、怎么写。真实实现在 Android 侧要接到 `TimetableCourseService` +
 * provider（属 Lead 接线），本泳道只定契约，并用假 host 把协议行为测穿。
 *
 * **全部同步**：Dart 侧是 `Future`，Kotlin 侧刻意定成阻塞式——服务端本来就是
 * 「一个连接一个工作线程」，阻塞在这里不占主线程。真实实现若要调 `suspend` 接口，
 * 在适配器里用 `runBlocking` 包一层即可（该线程不是主线程）。
 */
interface LanEditHost {
    fun ensureInitialized()

    val activeProfileId: String?

    val activeProfileName: String?

    /** 可切换的课表档案摘要；每条含 `id` / `name` / `courseCount` / `currentWeek` / `isActive`。 */
    fun listProfilesSummary(): List<Map<String, Any?>>

    val currentWeek: Int

    val semesterWeekCount: Int

    val courses: List<Course>

    fun findCourse(id: String): Course?

    fun createCourse(draft: Course): Course

    /** @return false 表示这条记录已经不在了（Dart 用 `StateError('course_not_found')` 表达同一件事）。 */
    fun updateCourse(course: Course): Boolean

    /** @return false 表示这条记录本来就不存在。 */
    fun deleteCourse(id: String): Boolean

    fun buildMetaJson(): Map<String, Any?>

    /** 设置当前周（Dart `LanEditHost.setCurrentWeek`）。 */
    fun setCurrentWeek(week: Int)

    /**
     * 切换激活档案（Dart `LanEditHost.switchProfile`）。
     *
     * @throws IllegalArgumentException 消息里含 `profile_not_found` / `profile_switch_failed`
     *   时路由映射成 404，其余 400（与 Dart 对 `ArgumentError` 的分支一致）。
     */
    fun switchProfile(profileId: String)

    /** 按 id 批量删除；返回真正删掉的条数（Dart `deleteCoursesBatch`）。 */
    fun deleteCoursesBatch(courseIds: List<String>): Int

    // ---------- B 组：更深的数据面（默认「不支持」→ 501，与 Dart 的可选能力同口径） ----------

    /** 整份备份导出（Dart `buildProfileBackupJson`）：当前课表的传输包 JSON。 */
    fun exportProfileBackupJson(): String =
        throw UnsupportedOperationException("profile_backup_export_unsupported")

    /**
     * 整份备份导入（Dart `importProfileBackupJson`）。
     *
     * **实现方必须先校验后落盘**：校验失败必须抛 [FormatException]（消息 = 错误码串），
     * 并且**一个字节都不许写**——导入是唯一能一次性覆盖用户全部课表的操作，
     * 半途写坏比直接拒绝严重得多。
     */
    fun importProfileBackupJson(content: String): Unit =
        throw UnsupportedOperationException("profile_backup_import_unsupported")

    /** 组替换（Dart `replaceCourseGroup`）：按课名整组替换，返回保存后的课。 */
    fun replaceCourseGroup(originalName: String?, slots: List<Course>): List<Course> =
        throw UnsupportedOperationException("course_group_replace_unsupported")

    /**
     * 表格导入（Dart `importSpreadsheetCourses`）。
     *
     * 解析器由实现方注入（见 WIRING-NOTE）：`pages/import` 不在 L0 的共享目录名单里，
     * 本层与适配器都不能静态依赖它，否则全队 L0 会 unresolved。
     */
    fun importSpreadsheetBytes(
        bytes: ByteArray,
        fileName: String,
        replaceExisting: Boolean,
    ): LanEditSpreadsheetImport =
        throw UnsupportedOperationException("spreadsheet_import_unsupported")
}

/**
 * 传输包迁移能力（对应 Dart `LanTransferHost`）：**能力与方法同源**。
 *
 * 具备此能力的宿主（如 [LanEditRepositoryHost]）在 `PUT /api/v1/profile/active`
 * 时会按统一传输协议拒绝直接覆写（409 transfer_preview_required），
 * 强制客户端先走 `/api/v1/import/preview` 确认差异，再走 `/api/v1/import/apply`。
 *
 * `previewTransferJson` / `applyTransferJson` 必须实现（Dart 侧同样是抽象方法，
 * 没有默认实现）；路由用 `host as? LanTransferHost` 判定能力，不支持时
 * `/import/preview` 回 501；`/import/apply` 在 `content` / `mode` 校验通过后才回 501
 * （缺字段仍是 400）。
 *
 * `undoTransferJson` 是**撤销点能力**（Kotlin 侧新增端点，Dart 的撤销点只在手机端
 * 消费、没有对应 HTTP 接口）：默认抛 `transfer_undo_not_supported` 让老宿主回 501，
 * 真实宿主 [LanEditRepositoryHost] 覆盖它。
 *
 * 不要把这三个方法声明回 [LanEditHost]——那会让
 * 「只实现数据面」的宿主也能回 preview 200，或出现「能力判定为真、执行却落到
 * 默认 null」的脱钩状态。
 */
interface LanTransferHost {
    fun previewTransferJson(content: String): Map<String, Any?>?
    fun applyTransferJson(content: String, mode: TransferApplyMode): Map<String, Any?>?

    /** 凭 `transferId` 撤回一次导入；不具备撤销能力的宿主抛异常 → 路由回 501。 */
    fun undoTransferJson(transferId: String): Map<String, Any?>? =
        throw UnsupportedOperationException("transfer_undo_not_supported")
}

/** 表格导入结果（Dart `SpreadsheetImportResult` 在 HTTP 层的投影）。 */
data class LanEditSpreadsheetImport(
    val importedCount: Int,
    val warnings: List<String>,
    val format: String,
)

/** 审计日志的一条。 */
data class LanEditAuditEntry(
    val category: String,
    val message: String,
    val extras: Map<String, Any?>,
    val atMillis: Long,
)

/**
 * 审计出口。Dart 侧落到 `AppLogService`；Kotlin 侧先定接口，
 * 真实落点由接线方接（本泳道不碰 `pages/diagnostics` 的日志设施）。
 *
 * 分类串与 Dart **逐字一致**（`lan_edit_auth_failed` / `lan_edit_course_created` …），
 * 这样两边日志能对上，排查时不用做映射表。
 */
interface LanEditAuditSink {
    fun info(category: String, message: String, extras: Map<String, Any?> = emptyMap())
}

/** 什么都不记（默认值，避免调用方为了「不想记日志」写一个匿名实现）。 */
object LanEditAuditNoop : LanEditAuditSink {
    override fun info(category: String, message: String, extras: Map<String, Any?>) = Unit
}

/** 内存环形缓冲：够测试与「最近活动」展示用，容量满了丢最旧。 */
class LanEditAuditRingBuffer(
    private val capacity: Int = 200,
    private val clock: () -> Long = System::currentTimeMillis,
) : LanEditAuditSink {
    private val entries = ArrayDeque<LanEditAuditEntry>()

    override fun info(category: String, message: String, extras: Map<String, Any?>) {
        synchronized(entries) {
            entries.addLast(LanEditAuditEntry(category, message, extras, clock()))
            while (entries.size > capacity) entries.removeFirst()
        }
    }

    fun snapshot(): List<LanEditAuditEntry> = synchronized(entries) { entries.toList() }

    fun categories(): List<String> = snapshot().map { it.category }
}

/**
 * 局域网编辑 HTTP API 的路由与业务规则（对应 Dart
 * `lib/services/lan_edit_api_handlers.dart`，只取第一切片需要的部分）。
 *
 * 与 Dart 逐条对齐的行为：
 * - `OPTIONS` 直接 204（CORS 预检不吃鉴权）；
 * - **跨源请求 403**：同网段任意网页都能连到手机，`Origin` 与请求 `Host` 不同就拒，
 *   `Origin: null` 或「一致的 host 不是本机 / 局域网私有网段」也拒（DNS rebinding 防线，
 *   判据在 `LanEditOriginPolicy`），否则逛一个陌生网站就能烧掉机主的 PIN 尝试次数；
 * - `/api/v1/health` 与 `/api/v1/auth/verify` 免鉴权，其余一律 Bearer 令牌；
 * - 写操作要过 `profileId` 三道闸（绑定 / 请求 / 当前激活），见 [ensureWriteProfileTarget]；
 * - JSON 体必须声明 `Content-Type: application/json`，否则 400（否则跨源 HTML 表单
 *   用 `text/plain` 就能绕开预检直接打进来）；
 * - 未鉴权路径上的异常一律 500 `internal_error`，**不回显异常原文**
 *   （Dart 原文：异常里的类型名 / 内部结构 / 绝对路径会变成对同网段的指纹）。
 *
 * **本类必须可并发使用**：一个请求一个线程，所以任何「先写字段、再读字段」的
 * 传值方式都会在并发下串台——所有判定都走返回值（[ProfileTarget] / 可空响应）。
 * 唯一共享的可变状态是 [tryEnter] 的并发计数，它在锁内自增。
 *
 * 状态码与响应体形状都照 Dart：`{"error":…,"message":…}`。
 */
class LanEditApiRouter(
    private val host: LanEditHost,
    private val session: LanEditSession,
    private val audit: LanEditAuditSink = LanEditAuditNoop,
    private val clock: () -> Long = System::currentTimeMillis,
) {

    private val lock = Any()
    private var inFlight = 0

    /** 返回 false 表示已按 503 拒掉，调用方不要再往下走（Dart `_inFlight` 同义）。 */
    fun tryEnter(): Boolean = synchronized(lock) {
        if (inFlight >= LanEditHttpLimits.MAX_CONCURRENT_REQUESTS) return false
        inFlight += 1
        return true
    }

    fun exit() {
        synchronized(lock) {
            if (inFlight > 0) inFlight -= 1
        }
    }

    /** 仅供测试断言并发计数归零。 */
    fun inFlightCount(): Int = synchronized(lock) { inFlight }

    /**
     * 会话是否已过期。给服务端的空闲看门狗用（Dart `_idleTimer` 每 30 秒查的就是它），
     * 也是服务端 `sessionExpired` 参数的默认值——**不传也会自动停服**。
     */
    val isSessionExpired: Boolean get() = session.isExpired

    /** 写目标判定结果。用返回值传，不用「先写字段再读」——并发下那种写法会串台。 */
    sealed interface ProfileTarget {
        data class Allowed(val profileId: String) : ProfileTarget
        data class Rejected(val response: LanEditHttpResponse) : ProfileTarget
    }

    fun route(request: LanEditHttpRequest): LanEditHttpResponse {
        try {
            if (request.method == "OPTIONS") {
                return LanEditHttpResponse.empty(204)
            }
            if (!request.isSameOrigin) {
                return LanEditHttpResponse.error(403, "cross_origin_forbidden", "Forbidden")
            }

            val path = request.path
            if (path == "/api/v1/health") {
                return LanEditHttpResponse.json(
                    200,
                    linkedMapOf<String, Any?>(
                        "ok" to true,
                        "serverTime" to isoNow(),
                    ),
                )
            }
            if (path == "/api/v1/auth/verify" && request.method == "POST") {
                return handleVerify(request)
            }
            authorize(request)?.let { return it }

            return when {
                path == "/api/v1/session" && request.method == "GET" -> handleGetSession()
                path == "/api/v1/session" && request.method == "PATCH" -> handlePatchSession(request)
                path == "/api/v1/profiles" && request.method == "GET" -> handleListProfiles()
                path == "/api/v1/profiles/switch" && request.method == "POST" -> handleSwitchProfile(request)
                path == "/api/v1/meta" && request.method == "GET" -> handleGetMeta()
                path == "/api/v1/profile/active" && request.method == "GET" -> handleExportProfileBackup()
                path == "/api/v1/profile/active" && request.method == "PUT" -> handleImportProfileBackup(request)
                path == "/api/v1/courses" && request.method == "GET" -> handleListCourses()
                path == "/api/v1/courses" && request.method == "POST" -> handleCreateCourse(request)
                path == "/api/v1/courses/group" && request.method == "PUT" -> handleReplaceCourseGroup(request)
                path == "/api/v1/courses/batch-delete" && request.method == "POST" -> handleBatchDeleteCourses(request)
                path == "/api/v1/week-expression/parse" && request.method == "POST" -> handleParseWeekExpression(request)
                path == "/api/v1/import/preview" && request.method == "POST" -> handleTransferPreview(request)
                path == "/api/v1/import/spreadsheet" && request.method == "POST" -> handleSpreadsheetImport(request)
                path == "/api/v1/import/apply" && request.method == "POST" -> handleTransferApply(request)
                path == "/api/v1/import/undo" && request.method == "POST" -> handleTransferUndo(request)
                // Dart：能力宿主（LanTransferHost）回 409，强制走「先 preview 再 apply」；
                // legacy host 会真正合并回 200。Kotlin 统一 409 是端点级差异
                //（WIRING-NOTE §三 B3 #19），生产宿主恒具备能力，生产行为一致。
                path == "/api/v1/import/merge" && request.method == "POST" -> handleLegacyImportRejected()
                else -> handleCourseById(request, path)
            }
        } catch (error: LanEditHttpException) {
            return LanEditHttpResponse.error(
                error.failure.status,
                error.failure.error,
                error.detail.ifEmpty { error.failure.error },
            )
        } catch (error: FormatException) {
            // 坏请求体是调用方的问题，不是服务端故障（Dart 原文：这些以前落到通用
            // 分支回 500 并把 Dart 异常原文回显出去）。
            return LanEditHttpResponse.error(statusForBodyFormatError(error), "invalid_request", formatMessage(error))
        } catch (error: UnsupportedOperationException) {
            // host 没实现这条可选能力（Dart 用 `host is LanTransferHost` 判，语义等价）：
            // 501 Not Implemented，错误码就用能力名，前端据此禁用对应入口。
            val capability = error.message.orEmpty().ifEmpty { "not_supported" }
            return LanEditHttpResponse.error(501, capability, capability)
        } catch (error: IllegalArgumentException) {
            // Dart 各处 `on ArgumentError` 统一回 400 invalid_request，消息即错误码
            //（`FormatException` 是它的子类，上面那条已经先接走了）。
            // 周次表达式解析失败（WeekExpressionException 是 IAE 子类）也走这里，
            // 统一 400 invalid_request，对应 Dart 的 FormatException 分支。
            return LanEditHttpResponse.error(400, "invalid_request", error.message ?: "invalid_request")
        } catch (error: Throwable) {
            // 未鉴权路径上的兜底：异常原文（类型名 / provider 内部结构 / 绝对路径）
            // 不能回给同网段的任意请求方，那等于一台没配对的设备也能拿本 App 做指纹。
            audit.info("lan_edit_internal_error", "internal_error", mapOf("type" to error::class.simpleName))
            return LanEditHttpResponse.error(500, "internal_error", "internal_error")
        }
    }

    // -----------------------------------------------------------------------
    // 鉴权
    // -----------------------------------------------------------------------

    private fun handleVerify(request: LanEditHttpRequest): LanEditHttpResponse {
        val clientIp = request.remoteAddress
        if (session.isExpired) {
            audit.info(
                "lan_edit_auth_failed",
                "auth failed",
                mapOf("reason" to "session_expired", "clientIp" to clientIp),
            )
            return LanEditHttpResponse.error(401, "session_expired", "Session expired")
        }
        if (session.isPinRateLimited(clientIp)) {
            audit.info(
                "lan_edit_auth_failed",
                "auth failed",
                mapOf("reason" to "rate_limited", "clientIp" to clientIp),
            )
            return LanEditHttpResponse.error(429, "rate_limited", "Too many PIN attempts")
        }
        val body = readJsonBody(request)
        val pin = body["pin"]?.toString().orEmpty()
        if (!session.verifyPin(pin, clientIp)) {
            audit.info(
                "lan_edit_auth_failed",
                "auth failed",
                mapOf("reason" to "invalid_pin", "clientIp" to clientIp),
            )
            return LanEditHttpResponse.error(401, "invalid_pin", "Invalid PIN")
        }
        return LanEditHttpResponse.json(
            200,
            linkedMapOf<String, Any?>(
                "token" to session.token,
                "expiresAt" to iso(session.expiresAt),
            ),
        )
    }

    /** @return null = 放行；非 null = 直接回这个响应。 */
    private fun authorize(request: LanEditHttpRequest): LanEditHttpResponse? {
        val clientIp = request.remoteAddress
        if (session.isExpired) {
            audit.info(
                "lan_edit_auth_failed",
                "auth failed",
                mapOf("reason" to "session_expired", "clientIp" to clientIp),
            )
            return LanEditHttpResponse.error(401, "session_expired", "Session expired")
        }
        val token = request.bearerToken
        if (!session.verifyTokenForRequest(token, clientIp)) {
            audit.info(
                "lan_edit_auth_failed",
                "auth failed",
                mapOf(
                    "reason" to if (token.isNullOrEmpty()) "missing_token" else "invalid_token",
                    "clientIp" to clientIp,
                ),
            )
            return LanEditHttpResponse.error(401, "unauthorized", "Unauthorized")
        }
        return null
    }

    // -----------------------------------------------------------------------
    // 读
    // -----------------------------------------------------------------------

    private fun handleGetSession(): LanEditHttpResponse {
        host.ensureInitialized()
        if (session.boundProfileId == null) session.boundProfileId = host.activeProfileId
        return LanEditHttpResponse.json(
            200,
            linkedMapOf<String, Any?>(
                "profileId" to host.activeProfileId,
                "profileName" to host.activeProfileName,
                "profiles" to host.listProfilesSummary(),
                "activeWeek" to host.currentWeek,
                "semesterWeekCount" to host.semesterWeekCount,
                "serverTime" to isoNow(),
                "expiresAt" to iso(session.expiresAt),
            ),
        )
    }

    private fun handleListCourses(): LanEditHttpResponse {
        host.ensureInitialized()
        return LanEditHttpResponse.json(
            200,
            linkedMapOf<String, Any?>("courses" to host.courses.map { it.toJson() }),
        )
    }

    /** `GET /api/v1/meta`：节次表 / 学期周数一类元信息（Dart 直接回 `host.buildMetaJson()`）。 */
    private fun handleGetMeta(): LanEditHttpResponse {
        host.ensureInitialized()
        return LanEditHttpResponse.json(200, host.buildMetaJson())
    }

    /** `GET /api/v1/profiles`：可切换档案摘要（Dart 同形）。 */
    private fun handleListProfiles(): LanEditHttpResponse {
        host.ensureInitialized()
        return LanEditHttpResponse.json(
            200,
            linkedMapOf<String, Any?>(
                "activeProfileId" to host.activeProfileId,
                "profiles" to host.listProfilesSummary(),
            ),
        )
    }

    /**
     * `PATCH /api/v1/session`：切当前周（Dart `_handlePatchSession`）。
     *
     * 两道校验：必须是数字且 ≥ 1；不能超过学期周数。Dart 的 message 是中文
     * （`currentWeek 无效` / `currentWeek 不能超过学期周数 N`），Kotlin 侧按仓库
     * i18n 纪律不写中文字面量，改用等义的错误码串——**错误码 `invalid_request` 与状态码不变**，
     * 只有 message 文本不同（已记入 WIRING-NOTE 的差异表）。
     */
    private fun handlePatchSession(request: LanEditHttpRequest): LanEditHttpResponse {
        host.ensureInitialized()
        val body = readJsonBody(request)
        when (val target = ensureWriteProfileTarget(request, body)) {
            is ProfileTarget.Rejected -> return target.response
            is ProfileTarget.Allowed -> Unit
        }
        val week = (body["currentWeek"] as? Number)?.toInt()
        if (week == null || week < 1) {
            return LanEditHttpResponse.error(400, "invalid_request", "current_week_invalid")
        }
        if (week > host.semesterWeekCount) {
            return LanEditHttpResponse.error(
                400,
                "invalid_request",
                "current_week_exceeds_semester_weeks:${host.semesterWeekCount}",
            )
        }
        host.setCurrentWeek(week)
        audit.info("lan_edit_current_week_set", "current week set", mapOf("currentWeek" to week))
        return LanEditHttpResponse.json(200, linkedMapOf<String, Any?>("currentWeek" to host.currentWeek))
    }

    /**
     * `POST /api/v1/profiles/switch`：切换激活档案（Dart `_handleSwitchProfile`）。
     *
     * 注意它**不走**写目标三道闸（那是给课表写入用的）：这里本来就是换档案，
     * 换完把会话绑定值重置成新的激活档案。
     */
    private fun handleSwitchProfile(request: LanEditHttpRequest): LanEditHttpResponse {
        host.ensureInitialized()
        val body = readJsonBody(request)
        val profileId = body["profileId"]?.toString()?.trim().orEmpty()
        if (profileId.isEmpty()) {
            return LanEditHttpResponse.error(400, "invalid_request", "profile_id_required")
        }
        try {
            host.switchProfile(profileId)
        } catch (error: IllegalArgumentException) {
            val message = error.message.orEmpty()
            val notFound = message.contains("profile_not_found") || message.contains("profile_switch_failed")
            return LanEditHttpResponse.error(
                if (notFound) 404 else 400,
                if (notFound) "not_found" else "invalid_request",
                message.ifEmpty { "profile_switch_failed" },
            )
        }
        session.boundProfileId = host.activeProfileId
        audit.info(
            "lan_edit_profile_switched",
            "profile switched",
            mapOf("profileId" to host.activeProfileId, "profileName" to host.activeProfileName),
        )
        return LanEditHttpResponse.json(
            200,
            linkedMapOf<String, Any?>(
                "profileId" to host.activeProfileId,
                "profileName" to host.activeProfileName,
                "profiles" to host.listProfilesSummary(),
                "meta" to host.buildMetaJson(),
            ),
        )
    }

    /** `POST /api/v1/courses/batch-delete`：按 id 批量删（Dart `_handleBatchDeleteCourses`）。 */
    private fun handleBatchDeleteCourses(request: LanEditHttpRequest): LanEditHttpResponse {
        host.ensureInitialized()
        val body = readJsonBody(request)
        when (val target = ensureWriteProfileTarget(request, body)) {
            is ProfileTarget.Rejected -> return target.response
            is ProfileTarget.Allowed -> Unit
        }
        val rawIds = body["ids"]
        if (rawIds !is List<*> || rawIds.isEmpty()) {
            return LanEditHttpResponse.error(400, "invalid_request", "ids_required")
        }
        val ids = rawIds.map { it.toString() }
        val deletedCount = host.deleteCoursesBatch(ids)
        audit.info(
            "lan_edit_courses_batch_deleted",
            "courses batch deleted",
            mapOf("deletedCount" to deletedCount, "requested" to ids.size),
        )
        return LanEditHttpResponse.json(200, linkedMapOf<String, Any?>("deletedCount" to deletedCount))
    }

    /**
     * `POST /api/v1/week-expression/parse`：把「1-16周 单周」这类表达式解析成周次数组
     * （Dart `_handleParseWeekExpression`）。**不需要写目标档案**——它是纯计算。
     *
     * `itemName` 只影响 warning 文案，Dart 缺省是本地化的「课程」；Kotlin 侧缺省空串
     * （不写中文字面量），网页端本来每次都会带上它。
     */
    private fun handleParseWeekExpression(request: LanEditHttpRequest): LanEditHttpResponse {
        host.ensureInitialized()
        val body = readJsonBody(request)
        val expression = body["expression"]?.toString()?.trim().orEmpty()
        if (expression.isEmpty()) {
            return LanEditHttpResponse.error(400, "invalid_request", "expression_required")
        }
        val itemName = body["itemName"]?.toString()?.trim().orEmpty()
        val warnings = mutableListOf<String>()
        val weeks = WeekExpressionParser.parse(
            raw = expression,
            itemName = itemName,
            semesterWeekCount = host.semesterWeekCount,
            warnings = warnings,
        )
        return LanEditHttpResponse.json(
            200,
            linkedMapOf<String, Any?>("weeks" to weeks, "warnings" to warnings),
        )
    }

    // -----------------------------------------------------------------------
    // 写
    // -----------------------------------------------------------------------

    private fun handleCreateCourse(request: LanEditHttpRequest): LanEditHttpResponse {
        host.ensureInitialized()
        val body = readJsonBody(request)
        val profileId = when (val target = ensureWriteProfileTarget(request, body)) {
            is ProfileTarget.Rejected -> return target.response
            is ProfileTarget.Allowed -> target.profileId
        }
        val draft = courseFromApiJson(body)
        if (draft.name.trim().isEmpty()) {
            return LanEditHttpResponse.error(400, "invalid_request", "course_name_required")
        }
        val created = host.createCourse(draft)
        audit.info(
            "lan_edit_course_created",
            "course created",
            mapOf("courseId" to created.id, "courseName" to created.name, "profileId" to profileId),
        )
        return LanEditHttpResponse.json(201, created.toJson())
    }

    private fun handleCourseById(request: LanEditHttpRequest, path: String): LanEditHttpResponse {
        val id = matchCourseId(path) ?: return LanEditHttpResponse.error(404, "not_found", "Resource not found")
        return when (request.method) {
            "GET" -> handleGetCourse(id)
            "PATCH" -> handlePatchCourse(request, id)
            "DELETE" -> handleDeleteCourse(request, id)
            // Dart 对「路径认识但方法不对」的组合也回 404（不是 405）：路由是
            // 路径 + 方法的联合判断，落到最后就是 not_found。
            else -> LanEditHttpResponse.error(404, "not_found", "Resource not found")
        }
    }

    private fun handleGetCourse(courseId: String): LanEditHttpResponse {
        host.ensureInitialized()
        val course = host.findCourse(courseId)
            ?: return LanEditHttpResponse.error(404, "not_found", "Course not found")
        return LanEditHttpResponse.json(200, course.toJson())
    }

    private fun handlePatchCourse(request: LanEditHttpRequest, courseId: String): LanEditHttpResponse {
        host.ensureInitialized()
        val existing = host.findCourse(courseId)
            ?: return LanEditHttpResponse.error(404, "not_found", "Course not found")
        val patch = readJsonBody(request)
        val profileId = when (val target = ensureWriteProfileTarget(request, patch)) {
            is ProfileTarget.Rejected -> return target.response
            is ProfileTarget.Allowed -> target.profileId
        }
        val merged = mergeCoursePatch(existing, patch)
        if (merged.name.trim().isEmpty()) {
            return LanEditHttpResponse.error(400, "invalid_request", "course_name_required")
        }
        if (!host.updateCourse(merged)) {
            // 预检之后到真正写入之间课程被删掉：必须回 404，不能回 200
            // 让浏览器显示「已保存」（Dart 原文的 StateError('course_not_found') 分支）。
            return LanEditHttpResponse.error(404, "not_found", "Course not found")
        }
        audit.info(
            "lan_edit_course_updated",
            "course updated",
            mapOf("courseId" to merged.id, "courseName" to merged.name, "profileId" to profileId),
        )
        return LanEditHttpResponse.json(200, merged.toJson())
    }

    private fun handleDeleteCourse(request: LanEditHttpRequest, courseId: String): LanEditHttpResponse {
        host.ensureInitialized()
        val profileId = when (val target = ensureWriteProfileTarget(request, null)) {
            is ProfileTarget.Rejected -> return target.response
            is ProfileTarget.Allowed -> target.profileId
        }
        val existing = host.findCourse(courseId)
            ?: return LanEditHttpResponse.error(404, "not_found", "Course not found")
        if (!host.deleteCourse(courseId)) {
            return LanEditHttpResponse.error(404, "not_found", "Course not found")
        }
        audit.info(
            "lan_edit_course_deleted",
            "course deleted",
            mapOf("courseId" to courseId, "courseName" to existing.name, "profileId" to profileId),
        )
        return LanEditHttpResponse.json(200, linkedMapOf<String, Any?>("deleted" to true, "id" to courseId))
    }

    private fun handleTransferPreview(request: LanEditHttpRequest): LanEditHttpResponse {
        host.ensureInitialized()
        when (val target = ensureWriteProfileTarget(request, null)) {
            is ProfileTarget.Rejected -> return target.response
            is ProfileTarget.Allowed -> Unit
        }
        val content = request.body
        if (content.trim().isEmpty()) {
            return LanEditHttpResponse.error(400, "invalid_request", "backup_content_required")
        }
        val preview = try {
            (host as? LanTransferHost)?.previewTransferJson(content)
        } catch (error: FormatException) {
            return LanEditHttpResponse.error(400, "invalid_request", formatMessage(error))
        }
        if (preview == null) {
            return LanEditHttpResponse.error(
                501,
                "transfer_preview_not_supported",
                "transfer_preview_not_supported",
            )
        }
        return LanEditHttpResponse.json(200, preview)
    }

    // -----------------------------------------------------------------------
    // B 组：整份备份 / 组替换 / 表格导入 / 传输包应用
    // -----------------------------------------------------------------------

    /**
     * `GET /api/v1/profile/active`：整份备份导出（Dart 直接回
     * `jsonDecode(host.buildProfileBackupJson())`，即一个传输包 JSON 对象）。
     */
    private fun handleExportProfileBackup(): LanEditHttpResponse {
        host.ensureInitialized()
        val content = host.exportProfileBackupJson()
        val decoded = MiniJson.tryParse(content)
        if (decoded !is Map<*, *>) {
            // 导出的内容连 JSON 对象都不是：这是服务端自己的 bug，不能把它当 200 发出去。
            return LanEditHttpResponse.error(500, "internal_error", "internal_error")
        }
        return LanEditHttpResponse.json(200, decoded)
    }

    /**
     * `PUT /api/v1/profile/active`：整份备份导入（Dart `_handleImportProfile`）。
     *
     * 传输包能力严格对齐 Dart：具备传输包能力时回 409（强制先 preview 再 apply）；
     * 仅未实现传输包能力的轻量/遗留测试 host 走 legacy 导入路径。
     *
     * 请求体是**裸 JSON**（Dart 这里用 `_readBody` 而不是 `_readJsonBody`，不校验 Content-Type）。
     * 「先校验后落盘」由 host 实现保证（见 [LanEditHost.importProfileBackupJson] 的契约）。
     */
    private fun handleImportProfileBackup(request: LanEditHttpRequest): LanEditHttpResponse {
        if (host is LanTransferHost) {
            return handleLegacyImportRejected()
        }
        host.ensureInitialized()
        when (val target = ensureWriteProfileTarget(request, null)) {
            is ProfileTarget.Rejected -> return target.response
            is ProfileTarget.Allowed -> Unit
        }
        val content = request.body
        if (content.trim().isEmpty()) {
            return LanEditHttpResponse.error(400, "invalid_request", "backup_content_required")
        }
        try {
            host.importProfileBackupJson(content)
        } catch (error: FormatException) {
            return LanEditHttpResponse.error(400, "invalid_request", formatMessage(error))
        }
        audit.info("lan_edit_profile_imported", "profile backup imported", mapOf("bytes" to content.length))
        return LanEditHttpResponse.json(200, linkedMapOf<String, Any?>("imported" to true))
    }

    /**
     * `PUT /api/v1/courses/group`：按课名整组替换（Dart `_handleReplaceCourseGroup`）。
     *
     * `slots` 必须是非空数组；第一门课的课名不能为空（Dart 的 `course_name_required`）。
     * **周次表达式只在这里解析**：每个 slot 的 `weekExpression` /
     * `suspendedWeekExpression` 经 [WeekExpressionParser.applyWeekExpressionFields]
     * 展开成 `customWeeks` / `suspendedWeeks`（与 Dart 的唯一调用点一致）。
     * 返回保存后的整组课。
     */
    private fun handleReplaceCourseGroup(request: LanEditHttpRequest): LanEditHttpResponse {
        host.ensureInitialized()
        val body = readJsonBody(request)
        when (val target = ensureWriteProfileTarget(request, body)) {
            is ProfileTarget.Rejected -> return target.response
            is ProfileTarget.Allowed -> Unit
        }
        val originalName = body["originalName"]?.toString()
        val rawSlots = body["slots"]
        if (rawSlots !is List<*> || rawSlots.isEmpty()) {
            return LanEditHttpResponse.error(400, "invalid_request", "at_least_one_schedule_slot")
        }
        val slots = ArrayList<Course>(rawSlots.size)
        for (item in rawSlots) {
            if (item !is Map<*, *>) {
                return LanEditHttpResponse.error(400, "invalid_request", "invalid_slot_entry")
            }
            @Suppress("UNCHECKED_CAST")
            val slotMap = LinkedHashMap<String, Any?>(item as Map<String, Any?>)
            // Dart：课名缺省回落 originalName，再回落「课程」；这里不给中文字面量兜底，
            // 缺名就交给下面的 course_name_required 拒掉（差异已记入 WIRING-NOTE）。
            val name = slotMap["name"]?.toString()?.trim()
            if (name.isNullOrEmpty() && !originalName.isNullOrEmpty()) {
                slotMap["name"] = originalName
            }
            WeekExpressionParser.applyWeekExpressionFields(
                slotMap = slotMap,
                courseName = slotMap["name"]?.toString()?.trim().orEmpty(),
                semesterWeekCount = host.semesterWeekCount,
            )
            slots.add(courseFromApiJson(slotMap))
        }
        if (slots.first().name.trim().isEmpty()) {
            return LanEditHttpResponse.error(400, "invalid_request", "course_name_required")
        }
        val saved = try {
            host.replaceCourseGroup(originalName, slots)
        } catch (error: FormatException) {
            return LanEditHttpResponse.error(400, "invalid_request", formatMessage(error))
        }
        audit.info(
            "lan_edit_course_group_saved",
            "course group saved",
            mapOf(
                "originalName" to originalName,
                "courseName" to saved.firstOrNull()?.name,
                "scheduleCount" to saved.size,
            ),
        )
        return LanEditHttpResponse.json(
            200,
            linkedMapOf<String, Any?>("courses" to saved.map { it.toJson() }),
        )
    }

    /**
     * `POST /api/v1/import/spreadsheet`：表格导入（Dart `_handleSpreadsheetImport`）。
     *
     * `contentBase64` 是**必填**且必须能 base64 解码；解析与落盘都在 host 里
     * （解析器由接线方注入，见 [LanEditHost.importSpreadsheetBytes]）。
     */
    private fun handleSpreadsheetImport(request: LanEditHttpRequest): LanEditHttpResponse {
        host.ensureInitialized()
        val body = readJsonBody(request)
        when (val target = ensureWriteProfileTarget(request, body)) {
            is ProfileTarget.Rejected -> return target.response
            is ProfileTarget.Allowed -> Unit
        }
        val fileName = body["fileName"]?.toString().orEmpty().ifEmpty { "import.csv" }
        val encoded = body["contentBase64"]?.toString().orEmpty()
        if (encoded.trim().isEmpty()) {
            return LanEditHttpResponse.error(400, "invalid_request", "content_base64_required")
        }
        val bytes = try {
            Base64.getDecoder().decode(encoded.trim())
        } catch (_: IllegalArgumentException) {
            return LanEditHttpResponse.error(400, "invalid_request", "content_base64_invalid")
        }
        val replaceExisting = body["replaceExisting"] == true
        val outcome = try {
            host.importSpreadsheetBytes(bytes, fileName, replaceExisting)
        } catch (error: FormatException) {
            return LanEditHttpResponse.error(400, "invalid_request", formatMessage(error))
        }
        if (outcome.importedCount > 0) {
            audit.info(
                "lan_edit_spreadsheet_imported",
                "spreadsheet imported",
                mapOf(
                    "importedCount" to outcome.importedCount,
                    "replaceExisting" to replaceExisting,
                    "format" to outcome.format,
                ),
            )
        }
        return LanEditHttpResponse.json(
            200,
            linkedMapOf<String, Any?>(
                "importedCount" to outcome.importedCount,
                "warnings" to outcome.warnings,
                "format" to outcome.format,
            ),
        )
    }

    /**
     * `POST /api/v1/import/apply`：应用一份传输包（Dart `_handleTransferApply`）。
     *
     * `mode` 只认 `merge` / `overwrite`；host 不支持应用时 501
     * （Dart 对非 `LanTransferHost` 的 host 也回 501 `transfer_apply_not_supported`）。
     */
    private fun handleTransferApply(request: LanEditHttpRequest): LanEditHttpResponse {
        host.ensureInitialized()
        val body = readJsonBody(request)
        when (val target = ensureWriteProfileTarget(request, body)) {
            is ProfileTarget.Rejected -> return target.response
            is ProfileTarget.Allowed -> Unit
        }
        val content = body["content"]?.toString().orEmpty()
        val mode = when (body["mode"]?.toString()) {
            "merge" -> TransferApplyMode.MERGE
            "overwrite" -> TransferApplyMode.OVERWRITE
            else -> null
        }
        if (content.trim().isEmpty() || mode == null) {
            return LanEditHttpResponse.error(
                400,
                "invalid_request",
                "transfer_content_and_mode_required",
            )
        }
        val transferHost = host as? LanTransferHost
            ?: return LanEditHttpResponse.error(
                501,
                "transfer_apply_not_supported",
                "transfer_apply_not_supported",
            )
        val result = try {
            transferHost.applyTransferJson(content, mode)
        } catch (error: FormatException) {
            // Dart `_handleTransferApply` 的 `on FormatException` 分支：包不合法是
            // 请求本身的问题（400），不是服务器错误。没有这一段的话，F17 接线之后
            // 坏包会一路冒到兜底 500，与 Dart 口径不一致。
            return LanEditHttpResponse.error(400, "invalid_request", formatMessage(error))
        }
        if (result == null) {
            return LanEditHttpResponse.error(
                501,
                "transfer_apply_not_supported",
                "transfer_apply_not_supported",
            )
        }
        return LanEditHttpResponse.json(200, result)
    }

    /**
     * `POST /api/v1/import/undo`：凭 `transferId` 撤回这次导入。
     *
     * 请求体 `{transferId}`，返回 `{undo, transferId, restored, skipped, error?}`。
     * **这是 Kotlin 侧新增的端点**：Dart 的撤销点只在手机端 UI 消费，没有 HTTP
     * 对应物；网页端导入成功后拿 `apply` 回包里的 `transferId` 调这里（WIRING-NOTE B2）。
     *
     * 撤销点不存在 / 已经撤销过都回 **200 + `undo:false` + 错误码**（与 apply 用
     * `applied:false + error` 表达业务失败同一形状），并且两种情况下都**不写盘**。
     * 缺 `transferId` 是请求本身的问题，回 400。
     */
    private fun handleTransferUndo(request: LanEditHttpRequest): LanEditHttpResponse {
        host.ensureInitialized()
        val body = readJsonBody(request)
        when (val target = ensureWriteProfileTarget(request, body)) {
            is ProfileTarget.Rejected -> return target.response
            is ProfileTarget.Allowed -> Unit
        }
        val transferId = body["transferId"]?.toString()?.trim().orEmpty()
        if (transferId.isEmpty()) {
            return LanEditHttpResponse.error(400, "invalid_request", "transfer_id_required")
        }
        val transferHost = host as? LanTransferHost
            ?: return LanEditHttpResponse.error(
                501,
                "transfer_undo_not_supported",
                "transfer_undo_not_supported",
            )
        val result = transferHost.undoTransferJson(transferId)
            ?: return LanEditHttpResponse.error(
                501,
                "transfer_undo_not_supported",
                "transfer_undo_not_supported",
            )
        if (result["undo"] == true) {
            audit.info(
                "lan_edit_transfer_undone",
                "transfer undo applied",
                mapOf("transferId" to transferId, "restored" to result["restored"]),
            )
        } else {
            audit.info(
                "lan_edit_transfer_undo_skipped",
                "transfer undo skipped",
                mapOf("transferId" to transferId, "reason" to result["error"]),
            )
        }
        return LanEditHttpResponse.json(200, result)
    }

    /**
     * 拒绝直接合并导入：回 409，要求先 `import/preview` 再 `import/apply` 并显式给 mode。
     *
     * Dart 只在宿主具备 `LanTransferHost` 时走这条（legacy host 会真正合并回 200，
     * `_handleMergeImport`）；Kotlin 对 legacy host 也一律 409，属端点级差异，
     * 见 WIRING-NOTE §三 B3 #19。生产宿主恒具备能力，生产行为与 Dart 一致。
     */
    private fun handleLegacyImportRejected(): LanEditHttpResponse = LanEditHttpResponse.error(
        409,
        "transfer_preview_required",
        "Use /api/v1/import/preview then /api/v1/import/apply with an explicit mode",
    )
    /**
     * 写目标三道闸（Dart `_ensureWriteProfileTarget` 原样）：
     * 1. `profileId` 从 body / query / `x-profile-id` / 会话绑定值里按优先级取，取不到 400；
     * 2. 与会话绑定值不一致 → 400 `profile_id_mismatch`（换了档案就重新握手）；
     * 3. 与当前激活档案不一致 → 409 `profile_mismatch`，并把三方 id 一起回给前端
     *    （前端据此提示「档案变了，刷新或切换」）。
     */
    private fun ensureWriteProfileTarget(
        request: LanEditHttpRequest,
        body: Map<String, Any?>?,
    ): ProfileTarget {
        host.ensureInitialized()
        if (session.boundProfileId == null) session.boundProfileId = host.activeProfileId

        val fromBody = body?.get("profileId")?.toString()?.trim()
        val fromQuery = request.queryParam("profileId")?.trim()
        val fromHeader = request.header("x-profile-id")?.trim()
        val requested = when {
            !fromBody.isNullOrEmpty() -> fromBody
            !fromQuery.isNullOrEmpty() -> fromQuery
            !fromHeader.isNullOrEmpty() -> fromHeader
            else -> session.boundProfileId?.trim()
        }
        if (requested.isNullOrEmpty()) {
            return ProfileTarget.Rejected(
                LanEditHttpResponse.error(
                    400,
                    "profile_id_required",
                    "profileId is required for write operations",
                ),
            )
        }
        val bound = session.boundProfileId?.trim()
        if (!bound.isNullOrEmpty() && bound != requested) {
            return ProfileTarget.Rejected(
                LanEditHttpResponse.error(
                    400,
                    "profile_id_mismatch",
                    "profileId does not match session-bound profile",
                ),
            )
        }
        val active = host.activeProfileId
        if (active != null && active != requested) {
            return ProfileTarget.Rejected(
                LanEditHttpResponse.json(
                    409,
                    linkedMapOf<String, Any?>(
                        "error" to "profile_mismatch",
                        "message" to "Active profile changed; refresh or switch profile",
                        "activeProfileId" to active,
                        "requestedProfileId" to requested,
                        "boundProfileId" to bound,
                    ),
                ),
            )
        }
        session.boundProfileId = requested
        return ProfileTarget.Allowed(requested)
    }

    // -----------------------------------------------------------------------
    // 请求体与课程构造
    // -----------------------------------------------------------------------

    private fun readJsonBody(request: LanEditHttpRequest): Map<String, Any?> {
        // 不校验 Content-Type 的话，跨源 HTML 表单能用 text/plain 发体打到这个 API：
        // 浏览器因此跳过 CORS 预检，请求照样落地（Dart 原文）。
        if (request.contentTypeMime != "application/json") {
            throw FormatException("unsupported_content_type")
        }
        val raw = request.body
        if (raw.isBlank()) return emptyMap()
        val decoded = MiniJson.tryParse(raw) ?: throw FormatException("Expected JSON object")
        @Suppress("UNCHECKED_CAST")
        return decoded as? Map<String, Any?> ?: throw FormatException("Expected JSON object")
    }

    /**
     * 建课：从对端 JSON 映射出 [Course]。
     *
     * **忽略周次表达式**（`weekExpression` / `suspendedWeekExpression`）——
     * Dart 只在 `PUT /api/v1/courses/group` 解析它们。建课时把表达式留着不解析，
     * 两字段并存时不会静默覆盖客户端给的 `customWeeks`。
     */
    private fun courseFromApiJson(body: Map<String, Any?>): Course {
        val normalized = LinkedHashMap<String, Any?>(body)
        val id = normalized["id"]?.toString()?.trim()
        if (id.isNullOrEmpty()) {
            normalized["id"] = UUID.randomUUID().toString()
        }
        fillDefaults(normalized)
        return Course.fromJson(normalized)
    }

    /**
     * PATCH：把补丁字段叠到既有记录上。
     *
     * **忽略周次表达式**（`weekExpression` / `suspendedWeekExpression`）——
     * 与 Dart 一致，改课不做表达式展开，不会覆盖既有的 `customWeeks`。
     */
    private fun mergeCoursePatch(existing: Course, patch: Map<String, Any?>): Course {
        val merged = LinkedHashMap<String, Any?>(existing.toJson())
        for ((key, value) in patch) {
            if (key == "id" || key == "profileId") continue
            merged[key] = value
        }
        merged["id"] = existing.id
        fillDefaults(merged)
        return Course.fromJson(merged)
    }

    /**
     * `Course.fromJson` 对 `teacher` / `location` / `startTime` / `endTime` 是必填
     * （缺了抛 `FormatException`）。局域网网页端只改「课名 / 星期 / 节次 / 周次」时
     * 不会带这些字段，所以缺省补空串——比让一次合法请求回 400 更合理，
     * 也与 Dart 侧这些字段默认可空的行为一致。
     */
    private fun fillDefaults(map: MutableMap<String, Any?>) {
        for (key in listOf("teacher", "location", "startTime", "endTime")) {
            if (map[key] == null) map[key] = ""
        }
    }

    private fun matchCourseId(path: String): String? {
        val prefix = "/api/v1/courses/"
        if (!path.startsWith(prefix)) return null
        val rest = path.substring(prefix.length)
        if (rest.isEmpty() || rest.contains('/')) return null
        return rest
    }

    private fun statusForBodyFormatError(error: FormatException): Int = when (formatMessage(error)) {
        "request_body_too_large" -> 413
        "request_body_timeout" -> 408
        else -> 400
    }

    private fun formatMessage(error: FormatException): String = error.message ?: "invalid_request"

    private fun isoNow(): String = iso(clock())

    /**
     * 时间戳格式**与 Dart 逐字一致**：`DateTime.now().toIso8601String()` 是**本地时间**
     * 且不带时区后缀（`2026-10-28T12:00:00.000`）。
     *
     * 早先这里用的是 `Instant.toString()`（UTC、带 `Z`）：语义上两者都是 ISO-8601、
     * 前端 `new Date()` 都能解，但**导出的备份包会因为 `Z` 过不了自己的校验**
     *（`DartTime.tryParseIso` 走 `LocalDateTime.parse`，2026-10-28 实测踩到），
     * 所以统一改成 Dart 口径，两侧不再有差异。
     */
    private fun iso(millis: Long): String = DartTime.toIso(
        Instant.ofEpochMilli(millis).atZone(ZoneId.systemDefault()).toLocalDateTime(),
    )
}
