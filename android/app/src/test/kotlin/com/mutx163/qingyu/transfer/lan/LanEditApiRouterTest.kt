package com.mutx163.qingyu.transfer.lan

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.share.LanEditSession
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * API 路由层单测（L0，无 socket）：状态码 / 响应体形状 / 鉴权与写目标三道闸 / 审计。
 *
 * 用 [FakeLanEditHost] 把「数据从哪来」这件事摘掉，只测协议行为；
 * 真 socket 往返在 `LanEditHttpServerTest`。
 * 期望值逐条对齐 Dart `lib/services/lan_edit_api_handlers.dart`。
 */
class LanEditApiRouterTest {

    private val now = 1_700_000_000_000L

    // -----------------------------------------------------------------------
    // 免鉴权路径
    // -----------------------------------------------------------------------

    @Test
    fun `health 免鉴权且回 ok 与服务器时间`() {
        val router = router()
        val response = router.route(get("/api/v1/health"))
        assertEquals(200, response.status)
        val body = json(response)
        assertEquals(true, body["ok"])
        assertNotNull(body["serverTime"])
        // ISO-8601（UTC）：前端 new Date(...) 两种都能解
        assertTrue(body["serverTime"].toString().contains("T"))
    }

    @Test
    fun `OPTIONS 预检直接 204 且不吃鉴权`() {
        val response = router().route(get("/api/v1/courses", method = "OPTIONS"))
        assertEquals(204, response.status)
        assertTrue(response.body.isEmpty())
    }

    @Test
    fun `跨源请求一律 403`() {
        val response = router().route(
            get("/api/v1/health", headers = mapOf("origin" to "http://evil.example", "host" to "192.168.1.5:8080")),
        )
        assertEquals(403, response.status)
        assertEquals("cross_origin_forbidden", json(response)["error"])
    }

    // -----------------------------------------------------------------------
    // 握手
    // -----------------------------------------------------------------------

    @Test
    fun `PIN 正确时发令牌 错误时 401`() {
        val session = session()
        val router = router(session = session)

        val ok = router.route(postJson("/api/v1/auth/verify", """{"pin":"${session.pin}"}"""))
        assertEquals(200, ok.status)
        assertEquals(session.token, json(ok)["token"])

        val bad = router.route(postJson("/api/v1/auth/verify", """{"pin":"000000"}"""))
        assertEquals(401, bad.status)
        assertEquals("invalid_pin", json(bad)["error"])
    }

    @Test
    fun `PIN 连错到单 IP 上限后回 429`() {
        val session = session()
        val router = router(session = session)
        repeat(LanEditSession.MAX_PIN_ATTEMPTS_PER_IP) {
            assertEquals(401, router.route(postJson("/api/v1/auth/verify", """{"pin":"000000"}""")).status)
        }
        val limited = router.route(postJson("/api/v1/auth/verify", """{"pin":"000000"}"""))
        assertEquals(429, limited.status)
        assertEquals("rate_limited", json(limited)["error"])
        // 限速生效后连正确 PIN 也不放行（不给攻击者「还差几位」的 oracle）
        assertEquals(429, router.route(postJson("/api/v1/auth/verify", """{"pin":"${session.pin}"}""")).status)
    }

    @Test
    fun `会话过期后握手与鉴权都回 session_expired`() {
        val expired = session(createdAtMillis = now - LanEditSession.MAX_DURATION_MILLIS - 1)
        val router = router(session = expired)
        val verify = router.route(postJson("/api/v1/auth/verify", """{"pin":"${expired.pin}"}"""))
        assertEquals(401, verify.status)
        assertEquals("session_expired", json(verify)["error"])

        val authorized = router.route(get("/api/v1/session", token = expired.token))
        assertEquals(401, authorized.status)
        assertEquals("session_expired", json(authorized)["error"])
    }

    @Test
    fun `缺令牌与错令牌都回 401 unauthorized`() {
        val session = session()
        val router = router(session = session)
        assertEquals("unauthorized", json(router.route(get("/api/v1/courses"))).get("error"))
        assertEquals("unauthorized", json(router.route(get("/api/v1/courses", token = "wrong"))).get("error"))
        assertEquals(200, router.route(get("/api/v1/courses", token = session.token)).status)
    }

    // -----------------------------------------------------------------------
    // 读
    // -----------------------------------------------------------------------

    @Test
    fun `会话信息带上档案 周次与过期时间`() {
        val session = session()
        val response = router(session = session).route(get("/api/v1/session", token = session.token))
        assertEquals(200, response.status)
        val body = json(response)
        assertEquals("p1", body["profileId"])
        assertEquals("默认课表", body["profileName"])
        // MiniJson 把 JSON 整数解析成 Long，所以期望值写 Long（不是 Int）
        assertEquals(7L, body["activeWeek"])
        assertEquals(20L, body["semesterWeekCount"])
        assertNotNull(body["expiresAt"])
        assertTrue(body["profiles"] is List<*>)
        // 首次读会话会把会话绑定到当前激活档案（Dart 行为）
        assertEquals("p1", session.boundProfileId)
    }

    @Test
    fun `课表读取返回课程数组`() {
        val host = FakeLanEditHost()
        host.seed(courseJson("c1", "高等数学"), courseJson("c2", "大学物理"))
        val session = session()
        val response = router(host = host, session = session).route(get("/api/v1/courses", token = session.token))
        assertEquals(200, response.status)
        val courses = json(response)["courses"] as List<*>
        assertEquals(2, courses.size)
        assertEquals("高等数学", (courses[0] as Map<*, *>)["name"])
    }

    // -----------------------------------------------------------------------
    // 写
    // -----------------------------------------------------------------------

    @Test
    fun `新建课程回 201 且 id 由服务端补`() {
        val host = FakeLanEditHost()
        val session = session(boundProfileId = "p1")
        val response = router(host = host, session = session).route(
            postJson("/api/v1/courses", """{"name":"线性代数","profileId":"p1"}""", token = session.token),
        )
        assertEquals(201, response.status)
        val body = json(response)
        assertEquals("线性代数", body["name"])
        assertTrue((body["id"] as String).isNotBlank())
        assertEquals(1, host.courses.size)
    }

    @Test
    fun `新建课程缺课名回 400 course_name_required`() {
        val session = session(boundProfileId = "p1")
        val response = router(session = session).route(
            postJson("/api/v1/courses", """{"name":"   ","profileId":"p1"}""", token = session.token),
        )
        assertEquals(400, response.status)
        assertEquals("course_name_required", json(response)["message"])
    }

    @Test
    fun `单课读取 修改 删除与 404`() {
        val host = FakeLanEditHost()
        host.seed(courseJson("c1", "高等数学"))
        val session = session(boundProfileId = "p1")
        val router = router(host = host, session = session)

        assertEquals(200, router.route(get("/api/v1/courses/c1", token = session.token)).status)
        assertEquals("Course not found", json(router.route(get("/api/v1/courses/nope", token = session.token)))["message"])

        val patched = router.route(
            jsonRequest("/api/v1/courses/c1", "PATCH", """{"teacher":"张老师","profileId":"p1"}""", session.token),
        )
        assertEquals(200, patched.status)
        assertEquals("张老师", json(patched)["teacher"])
        // 课名没被 patch 抹掉（合并而不是整份覆盖）
        assertEquals("高等数学", json(patched)["name"])

        val deleted = router.route(get("/api/v1/courses/c1", method = "DELETE", token = session.token))
        assertEquals(200, deleted.status)
        assertEquals(true, json(deleted)["deleted"])
        assertEquals(404, router.route(get("/api/v1/courses/c1", token = session.token)).status)
    }

    @Test
    fun `预检之后记录消失时修改必须回 404 而不是 200`() {
        val host = FakeLanEditHost()
        host.seed(courseJson("c1", "高等数学"))
        host.dropOnUpdate = true // 模拟「读到了、写的时候没了」
        val session = session(boundProfileId = "p1")
        val response = router(host = host, session = session).route(
            jsonRequest("/api/v1/courses/c1", "PATCH", """{"teacher":"张老师"}""", session.token),
        )
        assertEquals(404, response.status)
        assertEquals("Course not found", json(response)["message"])
    }

    // -----------------------------------------------------------------------
    // 请求体
    // -----------------------------------------------------------------------

    @Test
    fun `非 JSON 内容类型回 400`() {
        val session = session()
        val response = router(session = session).route(
            LanEditHttpRequest(
                method = "POST",
                target = "/api/v1/auth/verify",
                path = "/api/v1/auth/verify",
                query = emptyMap(),
                headers = mapOf("content-type" to "text/plain"),
                body = """{"pin":"1"}""",
                remoteAddress = "192.168.1.9",
            ),
        )
        assertEquals(400, response.status)
        assertEquals("unsupported_content_type", json(response)["message"])
    }

    @Test
    fun `坏 JSON 与顶层非对象都回 400`() {
        val router = router()
        assertEquals(400, router.route(postJson("/api/v1/auth/verify", "{not json")).status)
        assertEquals(400, router.route(postJson("/api/v1/auth/verify", "[1,2]")).status)
        // 空体按空对象处理（Dart 同口径），于是走到 PIN 校验而不是 400
        assertEquals(401, router.route(postJson("/api/v1/auth/verify", "")).status)
    }

    // -----------------------------------------------------------------------
    // 写目标三道闸
    // -----------------------------------------------------------------------

    @Test
    fun `没有可用 profileId 时写操作回 400`() {
        val host = FakeLanEditHost(activeProfileId = null)
        val session = session(boundProfileId = null)
        val response = router(host = host, session = session).route(
            postJson("/api/v1/courses", """{"name":"x"}""", token = session.token),
        )
        assertEquals(400, response.status)
        assertEquals("profile_id_required", json(response)["error"])
    }

    @Test
    fun `与会话绑定档案不一致回 400`() {
        val session = session(boundProfileId = "p1")
        val response = router(session = session).route(
            postJson("/api/v1/courses", """{"name":"x","profileId":"p2"}""", token = session.token),
        )
        assertEquals(400, response.status)
        assertEquals("profile_id_mismatch", json(response)["error"])
    }

    @Test
    fun `与当前激活档案不一致回 409 且带上三方 id`() {
        val host = FakeLanEditHost(activeProfileId = "p9")
        val session = session(boundProfileId = null)
        val response = router(host = host, session = session).route(
            postJson("/api/v1/courses", """{"name":"x","profileId":"p9"}""", token = session.token),
        )
        // 会话绑定值取的是 host.activeProfileId（p9），请求也带 p9 → 三道闸都过
        assertEquals(201, response.status)

        val session2 = session(boundProfileId = "p1")
        val mismatch = router(host = host, session = session2).route(
            postJson("/api/v1/courses", """{"name":"x","profileId":"p1"}""", token = session2.token),
        )
        assertEquals(409, mismatch.status)
        val body = json(mismatch)
        assertEquals("profile_mismatch", body["error"])
        assertEquals("p9", body["activeProfileId"])
        assertEquals("p1", body["requestedProfileId"])
        assertEquals("p1", body["boundProfileId"])
    }

    @Test
    fun `profileId 也可以来自查询串或请求头`() {
        val session = session(boundProfileId = "p1")
        val viaQuery = router(session = session).route(
            postJson("/api/v1/courses?profileId=p1", """{"name":"x"}""", token = session.token),
        )
        assertEquals(201, viaQuery.status)

        val session2 = session(boundProfileId = "p1")
        val viaHeader = router(session = session2).route(
            postJson(
                "/api/v1/courses",
                """{"name":"y"}""",
                token = session2.token,
                headers = mapOf("x-profile-id" to "p1"),
            ),
        )
        assertEquals(201, viaHeader.status)
    }

    // -----------------------------------------------------------------------
    // 预览（可选能力）
    // -----------------------------------------------------------------------

    @Test
    fun `host 不支持预览时回 501`() {
        val session = session(boundProfileId = "p1")
        val response = router(session = session).route(
            postJson("/api/v1/import/preview", """{"profileId":"p1"}""", token = session.token),
        )
        assertEquals(501, response.status)
        assertEquals("transfer_preview_not_supported", json(response)["error"])
    }

    @Test
    fun `host 支持预览时回 200 空体回 400`() {
        val host = FakeLanEditHost()
        host.previewResult = linkedMapOf<String, Any?>("transferId" to "t1", "diff" to emptyMap<String, Any?>())
        val session = session(boundProfileId = "p1")
        val router = router(host = host, session = session)

        val ok = router.route(
            LanEditHttpRequest(
                method = "POST",
                target = "/api/v1/import/preview",
                path = "/api/v1/import/preview",
                query = mapOf("profileId" to "p1"),
                headers = mapOf(
                    "content-type" to "application/json",
                    "authorization" to "Bearer ${session.token}",
                ),
                body = """{"a":1}""",
                remoteAddress = "192.168.1.9",
            ),
        )
        assertEquals(200, ok.status)
        assertEquals("t1", json(ok)["transferId"])

        val empty = router.route(
            postJson("/api/v1/import/preview", "", token = session.token),
        )
        assertEquals(400, empty.status)
        assertEquals("backup_content_required", json(empty)["message"])
    }

    // -----------------------------------------------------------------------
    // 兜底与并发
    // -----------------------------------------------------------------------

    @Test
    fun `未知路径回 404 且路径认识但方法不对也是 404`() {
        val session = session()
        val router = router(session = session)
        assertEquals("not_found", json(router.route(get("/api/v1/nope", token = session.token)))["error"])
        // Dart 的路由是「路径 + 方法」联合判断，落不到就是 not_found（不是 405）
        assertEquals(404, router.route(get("/api/v1/session", method = "DELETE", token = session.token)).status)
        assertEquals(404, router.route(get("/api/v1/courses", method = "PUT", token = session.token)).status)
        // 带斜杠的课 id 不匹配（`/api/v1/courses/a/b`）
        assertEquals(404, router.route(get("/api/v1/courses/a/b", token = session.token)).status)
    }

    @Test
    fun `未预期异常回 500 且不回显异常原文`() {
        val host = FakeLanEditHost()
        host.failWith = IllegalStateException("secret:/data/user/0/com.mutx163.qingyu/db.sqlite")
        val session = session()
        val response = router(host = host, session = session).route(get("/api/v1/courses", token = session.token))
        assertEquals(500, response.status)
        assertEquals("internal_error", json(response)["error"])
        assertEquals("internal_error", json(response)["message"])
        assertFalse(
            "异常原文（可能带绝对路径）绝不能回给同网段请求方",
            response.body.toString(Charsets.UTF_8).contains("db.sqlite"),
        )
    }

    @Test
    fun `并发计数满 16 后拒绝第 17 个并回 503`() {
        val router = router()
        repeat(LanEditHttpLimits.MAX_CONCURRENT_REQUESTS) { assertTrue(router.tryEnter()) }
        assertFalse("第 17 个必须被拒", router.tryEnter())
        assertEquals(LanEditHttpLimits.MAX_CONCURRENT_REQUESTS, router.inFlightCount())
        repeat(LanEditHttpLimits.MAX_CONCURRENT_REQUESTS) { router.exit() }
        assertEquals(0, router.inFlightCount())
        assertTrue("放干净后要能重新进", router.tryEnter())
        router.exit()
    }

    // -----------------------------------------------------------------------
    // 审计
    // -----------------------------------------------------------------------

    @Test
    fun `鉴权失败与课程写入都留审计 分类串与 Dart 一致`() {
        val host = FakeLanEditHost()
        val audit = LanEditAuditRingBuffer()
        val session = session(boundProfileId = "p1")
        val router = LanEditApiRouter(host = host, session = session, audit = audit, clock = { now })

        router.route(postJson("/api/v1/auth/verify", """{"pin":"000000"}"""))
        router.route(postJson("/api/v1/auth/verify", """{"pin":"${session.pin}"}"""))
        router.route(postJson("/api/v1/courses", """{"name":"线性代数","profileId":"p1"}""", token = session.token))
        router.route(get("/api/v1/courses/nope", token = session.token))
        router.route(get("/api/v1/courses/c1", method = "DELETE", token = session.token))

        val categories = audit.categories()
        assertTrue("失败鉴权要留痕", categories.contains("lan_edit_auth_failed"))
        assertTrue("建课要留痕", categories.contains("lan_edit_course_created"))
        assertEquals(1, categories.count { it == "lan_edit_auth_failed" })
    }

    @Test
    fun `审计环形缓冲容量满了丢最旧`() {
        val audit = LanEditAuditRingBuffer(capacity = 3, clock = { now })
        repeat(5) { audit.info("cat$it", "m", emptyMap()) }
        assertEquals(listOf("cat2", "cat3", "cat4"), audit.categories())
        assertEquals(now, audit.snapshot().first().atMillis)
    }

    // -----------------------------------------------------------------------
    // 工具
    // -----------------------------------------------------------------------

    private fun session(
        pin: String = "123456",
        token: String = "tok-abc",
        createdAtMillis: Long = now,
        lastActivityAtMillis: Long = now,
        boundProfileId: String? = null,
    ): LanEditSession = LanEditSession.forTest(
        pin = pin,
        token = token,
        createdAtMillis = createdAtMillis,
        lastActivityAtMillis = lastActivityAtMillis,
        boundProfileId = boundProfileId,
        clockMillis = { now },
    )

    private fun router(
        host: LanEditHost = FakeLanEditHost(),
        session: LanEditSession = session(),
    ): LanEditApiRouter = LanEditApiRouter(host = host, session = session, clock = { now })

    private fun get(
        target: String,
        method: String = "GET",
        token: String? = null,
        headers: Map<String, String> = emptyMap(),
    ): LanEditHttpRequest = build(target, method, headers, "", token)

    private fun postJson(
        target: String,
        body: String,
        token: String? = null,
        headers: Map<String, String> = emptyMap(),
    ): LanEditHttpRequest = build(target, "POST", headers + ("content-type" to "application/json"), body, token)

    private fun jsonRequest(
        target: String,
        method: String,
        body: String,
        token: String? = null,
    ): LanEditHttpRequest = build(target, method, mapOf("content-type" to "application/json"), body, token)

    private fun build(
        target: String,
        method: String,
        headers: Map<String, String>,
        body: String,
        token: String?,
    ): LanEditHttpRequest {
        val (path, queryString) = LanEditHttpParse.splitTarget(target)
        val allHeaders = LinkedHashMap<String, String>(headers)
        if (token != null) allHeaders["authorization"] = "Bearer $token"
        return LanEditHttpRequest(
            method = method,
            target = target,
            path = path,
            query = LanEditHttpParse.parseQuery(queryString),
            headers = allHeaders,
            body = body,
            remoteAddress = "192.168.1.9",
        )
    }

    @Suppress("UNCHECKED_CAST")
    private fun json(response: LanEditHttpResponse): Map<String, Any?> =
        MiniJson.tryParse(response.body.toString(Charsets.UTF_8)) as? Map<String, Any?> ?: emptyMap()

    private fun courseJson(id: String, name: String): Map<String, Any?> = linkedMapOf(
        "id" to id,
        "name" to name,
        "teacher" to "",
        "location" to "",
        "startTime" to "",
        "endTime" to "",
    )
}

/** 假 host：只实现这一层需要的数据面，把「数据从哪来」摘出协议测试。 */
internal class FakeLanEditHost(
    override var activeProfileId: String? = "p1",
) : LanEditHost {
    private val stored = mutableListOf<Course>()

    override var activeProfileName: String? = "默认课表"

    override var currentWeek: Int = 7

    override var semesterWeekCount: Int = 20

    var previewResult: Map<String, Any?>? = null

    var failWith: Throwable? = null

    /** 并发测试用：进入业务层前先卡住，用来证明「一个连接卡住不挡另一个连接」。 */
    var onEnsureInitialized: (() -> Unit)? = null

    /** 模拟「读到了、写的时候没了」：updateCourse 一律返回 false。 */
    var dropOnUpdate: Boolean = false

    override val courses: List<Course> get() = stored.toList()

    fun seed(vararg json: Map<String, Any?>) {
        json.forEach { stored.add(Course.fromJson(it)) }
    }

    override fun ensureInitialized() {
        onEnsureInitialized?.invoke()
        failWith?.let { throw it }
    }

    override fun listProfilesSummary(): List<Map<String, Any?>> = listOf(
        linkedMapOf(
            "id" to activeProfileId,
            "name" to activeProfileName,
            "courseCount" to stored.size,
            "currentWeek" to currentWeek,
            "isActive" to true,
        ),
    )

    override fun findCourse(id: String): Course? = stored.firstOrNull { it.id == id }

    override fun createCourse(draft: Course): Course {
        val created = if (draft.id.isBlank()) draft.copy(id = "generated-${stored.size + 1}") else draft
        stored.add(created)
        return created
    }

    override fun updateCourse(course: Course): Boolean {
        if (dropOnUpdate) return false
        val index = stored.indexOfFirst { it.id == course.id }
        if (index < 0) return false
        stored[index] = course
        return true
    }

    override fun deleteCourse(id: String): Boolean {
        val index = stored.indexOfFirst { it.id == id }
        if (index < 0) return false
        stored.removeAt(index)
        return true
    }

    override fun buildMetaJson(): Map<String, Any?> = linkedMapOf(
        "semesterWeekCount" to semesterWeekCount,
        "sections" to emptyList<Any?>(),
    )

    override fun previewTransferJson(content: String): Map<String, Any?>? {
        if (previewResult == null) return null
        if (content.trim().isEmpty()) throw com.mutx163.qingyu.core.FormatException("backup_content_required")
        return previewResult
    }
}
