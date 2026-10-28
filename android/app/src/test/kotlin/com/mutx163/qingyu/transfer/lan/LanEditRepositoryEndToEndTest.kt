package com.mutx163.qingyu.transfer.lan

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.share.LanEditSession
import com.mutx163.qingyu.sync.validateTransferPackageJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.io.InputStream
import java.net.InetAddress
import java.net.Socket
import java.time.LocalDateTime

/**
 * **端到端**：真 HTTP 请求 → 路由 → `LanEditRepositoryHost` → `TimetableRepository`
 * → `TimetableStore` → 内存 KV 存储。
 *
 * 为什么单独一组：前面几组要么只测路由（假 host，不碰数据），要么只测适配器（不碰 socket）。
 * 这一组是**唯一能证明「电脑端发来的请求真的落到盘上」**的地方，也是本轮验收里
 * 「坏备份一个字节都不许写」的最终证据——它必须穿过真实的 HTTP 栈。
 */
class LanEditRepositoryEndToEndTest {

    private val now = 1_700_000_000_000L

    @Test
    fun `坏备份走真 HTTP 导入 400 且盘上一字未变`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        repository.addCourse(course("keep1", "原有课程"))
        val before = store.rawSnapshot()
        val session = session()

        withServer(repository, session) { port ->
            val bad = """{"app":"mikcb","packageType":"transfer","schemaVersion":1,"packageId":"p1",""" +
                """"scope":"current_timetable","channel":"lan","exportedAt":"2026-10-28T09:00:00.000",""" +
                """"currentWeek":7,"courses":[{"id":"c9"}],"tasks":[],"scheduleItems":[],"exams":[],""" +
                """"timeSchemes":[],"scheduleDateRules":[],"locationTimeGroups":[],"profiles":[]}"""
            val response = parseResponse(exchange(port, put(port, "/api/v1/profile/active", bad, session.token)))
            assertEquals(400, response.status)
            assertTrue("错误码要说明是哪一条校验没过：${response.body}", response.body.contains("transfer_course_name_required"))
            assertEquals("HTTP 层也要保证盘上一字未变", before, store.rawSnapshot())
            assertEquals(1, repository.courses.size)
        }
    }

    @Test
    fun `导出再导入走真 HTTP 课程真的落到盘上`() {
        val sourceStore = InMemoryKeyValueStore()
        val source = repositoryOn(sourceStore)
        source.addCourse(course("c1", "高等数学"))
        source.addCourse(course("c2", "大学物理"))
        val session = session()

        withServer(source, session) { port ->
            val exported = parseResponse(
                exchange(port, get(port, "/api/v1/profile/active", session.token)),
            )
            assertEquals(200, exported.status)
            assertTrue("导出的必须是合法传输包", validateTransferPackageJson(exported.body).isValid)

            // 导到另一份空课表上
            val targetStore = InMemoryKeyValueStore()
            val target = repositoryOn(targetStore)
            withServer(target, session) { targetPort ->
                val imported = parseResponse(
                    exchange(targetPort, put(targetPort, "/api/v1/profile/active", exported.body, session.token)),
                )
                assertEquals(200, imported.status)
                assertTrue(imported.body.contains("\"imported\":true"))
                assertEquals(setOf("高等数学", "大学物理"), target.courses.map { it.name }.toSet())
                val raw = targetStore.rawSnapshot().values.joinToString("\n")
                assertTrue("盘上必须写着两门课", raw.contains("高等数学") && raw.contains("大学物理"))
            }
        }
    }

    @Test
    fun `组替换走真 HTTP 组里消失的课真的没了`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        repository.addCourse(course("g1", "高等数学", dayOfWeek = 1))
        repository.addCourse(course("g2", "高等数学", dayOfWeek = 3))
        repository.addCourse(course("other", "大学物理"))
        val session = session()

        withServer(repository, session) { port ->
            val body = """{"originalName":"高等数学","profileId":"p1","slots":[""" +
                """{"id":"g1","name":"高等数学","dayOfWeek":2,"startSection":1,"endSection":2,"startTime":"08:00","endTime":"09:40"},""" +
                """{"id":"g2","name":"高等数学","dayOfWeek":4,"startSection":1,"endSection":2,"startTime":"08:00","endTime":"09:40"}]}"""
            val response = parseResponse(exchange(port, put(port, "/api/v1/courses/group", body, session.token)))
            assertEquals(200, response.status)
            assertTrue(response.body.contains("\"courses\""))

            val ids = repository.courses.map { it.id }
            assertFalse("原来周三那条必须真的没了", ids.contains("g3"))
            assertEquals(3, repository.courses.size)
            assertEquals(setOf(2, 4), repository.courses.filter { it.name == "高等数学" }.map { it.dayOfWeek }.toSet())
            val raw = store.rawSnapshot().values.joinToString("\n")
            assertTrue("盘上要写着新排课", raw.contains("\"dayOfWeek\":4"))
        }
    }

    @Test
    fun `import_merge 真往返一律 409 要求先预览再应用`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        repository.addCourse(course("keep1", "原有课程"))
        val before = store.rawSnapshot()
        val session = session()

        withServer(repository, session) { port ->
            val response = parseResponse(
                exchange(port, post(port, "/api/v1/import/merge", """{"content":"{}"}""", session.token)),
            )
            assertEquals(409, response.status)
            assertTrue(response.body.contains("transfer_preview_required"))
            // 被拒的路径当然不许动盘
            assertEquals(before, store.rawSnapshot())
        }
    }

    @Test
    fun `import_apply 与 import_preview 在没有服务时真往返 501`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        val session = session()

        withServer(repository, session) { port ->
            val apply = parseResponse(
                exchange(
                    port,
                    post(port, "/api/v1/import/apply", """{"content":"{}","mode":"merge","profileId":"p1"}""", session.token),
                ),
            )
            assertEquals(501, apply.status)
            assertTrue(apply.body.contains("transfer_apply_not_supported"))

            val preview = parseResponse(
                exchange(port, post(port, "/api/v1/import/preview", """{"a":1}""", session.token)),
            )
            assertEquals(501, preview.status)
            assertTrue(preview.body.contains("transfer_preview_not_supported"))
        }
    }

    @Test
    fun `表格导入走真 HTTP 并按 replaceExisting 决定追加还是替换`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        repository.addCourse(course("old", "旧课"))
        val session = session()
        val parsed = LanEditSpreadsheetParse(
            courses = listOf(course("n1", "新课一"), course("n2", "新课二")),
            warnings = listOf("w1"),
            format = "csv",
        )

        withServer(repository, session, parser = { _, _, _ -> parsed }) { port ->
            val base64 = java.util.Base64.getEncoder().encodeToString("a,b\n1,2".toByteArray())
            val body = """{"fileName":"x.csv","contentBase64":"$base64","replaceExisting":true,"profileId":"p1"}"""
            val response = parseResponse(
                exchange(port, post(port, "/api/v1/import/spreadsheet", body, session.token)),
            )
            assertEquals(200, response.status)
            assertTrue(response.body.contains("\"importedCount\":2"))
            assertTrue(response.body.contains("\"format\":\"csv\""))
            assertEquals(setOf("n1", "n2"), repository.courses.map { it.id }.toSet())
        }
    }

    // -----------------------------------------------------------------------
    // 工具
    // -----------------------------------------------------------------------

    private fun withServer(
        repository: TimetableRepository,
        session: LanEditSession,
        parser: (ByteArray, String, TimetableSettings) -> LanEditSpreadsheetParse = { _, _, _ ->
            throw UnsupportedOperationException("spreadsheet_import_unsupported")
        },
        block: (Int) -> Unit,
    ) {
        val server = LanEditHttpServer(
            router = LanEditApiRouter(
                host = LanEditRepositoryHost(repository, parser),
                session = session,
                clock = { now },
            ),
            bindAddress = InetAddress.getByName("127.0.0.1"),
        )
        val port = server.start()
        try {
            block(port)
        } finally {
            server.stop("test_done")
        }
    }

    private fun repositoryOn(store: InMemoryKeyValueStore): TimetableRepository {
        val timetableStore = TimetableStore(store)
        val stamp = LocalDateTime.of(2026, 10, 28, 9, 0)
        timetableStore.saveProfiles(
            listOf(
                TimetableProfile(
                    id = "p1",
                    name = "默认课表",
                    currentWeek = 7,
                    createdAt = stamp,
                    lastUsedAt = stamp,
                ),
            ),
        )
        timetableStore.saveActiveProfileId("p1")
        timetableStore.saveSettings(TimetableSettings.defaults())
        timetableStore.saveCurrentWeek(7)
        return TimetableRepository(timetableStore)
    }

    private fun session(): LanEditSession = LanEditSession.forTest(
        pin = "123456",
        token = "tok-e2e",
        createdAtMillis = now,
        lastActivityAtMillis = now,
        boundProfileId = "p1",
        clockMillis = { now },
    )

    private fun course(id: String, name: String, dayOfWeek: Int = 1): Course = Course(
        id = id,
        name = name,
        teacher = "",
        location = "",
        dayOfWeek = dayOfWeek,
        startSection = 1,
        endSection = 2,
        startTime = "08:00",
        endTime = "09:40",
    )

    private fun get(port: Int, path: String, token: String): String =
        "GET $path HTTP/1.1\r\nHost: 127.0.0.1:$port\r\nAuthorization: Bearer $token\r\n\r\n"

    private fun put(port: Int, path: String, body: String, token: String): String {
        val bytes = body.toByteArray(Charsets.UTF_8)
        return "PUT $path HTTP/1.1\r\nHost: 127.0.0.1:$port\r\nContent-Type: application/json\r\n" +
            "Authorization: Bearer $token\r\nContent-Length: ${bytes.size}\r\n\r\n$body"
    }

    private fun post(port: Int, path: String, body: String, token: String): String {
        val bytes = body.toByteArray(Charsets.UTF_8)
        return "POST $path HTTP/1.1\r\nHost: 127.0.0.1:$port\r\nContent-Type: application/json\r\n" +
            "Authorization: Bearer $token\r\nContent-Length: ${bytes.size}\r\n\r\n$body"
    }

    private fun exchange(port: Int, request: String): String {
        Socket("127.0.0.1", port).use { socket ->
            socket.soTimeout = 10_000
            socket.getOutputStream().write(request.toByteArray(Charsets.UTF_8))
            socket.getOutputStream().flush()
            socket.shutdownOutput()
            return readAll(socket.getInputStream())
        }
    }

    /** 容忍 RST：服务端在错误响应后直接关连接时，已收到的字节仍然有效。 */
    private fun readAll(input: InputStream): String {
        val out = ByteArrayOutputStream()
        val buffer = ByteArray(4096)
        try {
            while (true) {
                val read = input.read(buffer)
                if (read < 0) break
                out.write(buffer, 0, read)
            }
        } catch (_: IOException) {
            // 忽略
        }
        return out.toByteArray().toString(Charsets.UTF_8)
    }

    private class ParsedResponse(val status: Int, val body: String)

    private fun parseResponse(raw: String): ParsedResponse {
        assertTrue("响应必须有头块：${raw.take(120)}", raw.contains("\r\n\r\n"))
        val splitAt = raw.indexOf("\r\n\r\n")
        val statusLine = raw.substring(0, raw.indexOf("\r\n"))
        val status = statusLine.split(' ')[1].toInt()
        return ParsedResponse(status, raw.substring(splitAt + 4))
    }
}
