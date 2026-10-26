package com.mutx163.qingyu.sync

import com.mutx163.qingyu.core.DartFormatException
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimeScheme
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 快照解析门 / 宽松列表解析 / meta 往返纯函数单测。
 *
 * 期望值来源：
 * - [Dart抄录] test/services/app_sync_snapshot_service_test.dart（997 行）逐条转录；
 * - [Dart推演] 按 app_sync_snapshot_service.dart 实现行号推演（门序/缺省值/宽松规则）；
 * - [人推] 人推边界（正交覆盖，不来自既有测试）。
 */
class AppSyncSnapshotCodecTest {

    /** 最小结构合法快照（app/schemaVersion/backupType/profiles/timeSchemes）。 */
    private fun baseSnapshot(): LinkedHashMap<String, Any?> = linkedMapOf(
        "app" to "mikcb",
        "schemaVersion" to 2L,
        "backupType" to "sync",
        "exportedAt" to "2026-03-22T09:00:00.000",
        "deviceId" to "device-1",
        "activeProfileId" to null,
        "profiles" to emptyList<Any?>(),
        "timeSchemes" to emptyList<Any?>(),
    )

    // ---------- 根解码 ----------

    @Test
    fun `decode rejects non-object root with payload invalid`() {
        // [Dart抄录] app_sync_snapshot_service_test.dart:489-492（jsonEncode([1,2,3])）
        try {
            decodeSnapshotObject("[1,2,3]")
            throw AssertionError("expected DartFormatException")
        } catch (e: DartFormatException) {
            assertEquals("invalid_sync_snapshot_payload", e.message)
        }
        try {
            decodeSnapshotObject("not json")
            throw AssertionError("expected DartFormatException")
        } catch (e: DartFormatException) {
            // JSON 解析失败本身按 Dart rethrow 语义不换文案（本侧保留解析器消息）
            assertFalse(e.message == "invalid_sync_snapshot_payload")
        }
    }

    // ---------- 信封 + 校验和对账 ----------

    @Test
    fun `envelope check passes minimal snapshot`() {
        // [Dart抄录] :494-526 门序的 Happy path
        val check = checkSnapshotEnvelopeAndChecksum(baseSnapshot())
        assertTrue(check.isValid)
        assertNull(check.errorCode)
        // 声明哈希缺失 → 跳过对账（Dart :522-524 expectedHash.isEmpty）
        assertEquals("", check.expectedHash)
        assertEquals(64, check.actualHash.length)
        // 去哈希载荷保留其余键
        assertTrue(check.payloadWithoutHash!!.containsKey("profiles"))
        assertFalse(check.payloadWithoutHash.containsKey("contentSha256"))
    }

    @Test
    fun `envelope rejects wrong app version or type`() {
        // [Dart抄录] :508-510（app!='mikcb' || version!=2 || type!='sync'）
        val wrongApp = baseSnapshot(); wrongApp["app"] = "other"
        assertEquals("unrecognized_sync_snapshot", checkSnapshotEnvelopeAndChecksum(wrongApp).errorCode)

        val wrongVersion = baseSnapshot(); wrongVersion["schemaVersion"] = 3L
        assertEquals("unrecognized_sync_snapshot", checkSnapshotEnvelopeAndChecksum(wrongVersion).errorCode)

        val wrongType = baseSnapshot(); wrongType["backupType"] = "backup"
        assertEquals("unrecognized_sync_snapshot", checkSnapshotEnvelopeAndChecksum(wrongType).errorCode)
    }

    @Test
    fun `envelope rejects malformed typed fields`() {
        // [Dart抄录] app_sync_snapshot_service_test.dart:494-517（app/schemaVersion/backupType/contentSha256 四键逐键投毒）
        val payload = baseSnapshot()
        val cases = mapOf<String, Any?>(
            "app" to 123L,
            "schemaVersion" to listOf("2"),
            "backupType" to mapOf("type" to "sync"),
            "contentSha256" to listOf("bad"),
        )
        for ((key, badValue) in cases) {
            val invalid = LinkedHashMap(payload)
            invalid[key] = badValue
            val expected = when (key) {
                "app", "schemaVersion", "backupType" -> "unrecognized_sync_snapshot"
                else -> "invalid_sync_snapshot_checksum"
            }
            assertEquals(key, expected, checkSnapshotEnvelopeAndChecksum(invalid).errorCode)
        }
    }

    @Test
    fun `envelope accepts integral double version like dart num equality`() {
        // [Dart推演] :500-505（rawVersion is! int && !(num && == toInt()) → 拒；
        // 2.0 是 num 且 == toInt → 收，再 toInt 成 2）
        val doubleVersion = baseSnapshot(); doubleVersion["schemaVersion"] = 2.0
        assertTrue(checkSnapshotEnvelopeAndChecksum(doubleVersion).isValid)

        val halfVersion = baseSnapshot(); halfVersion["schemaVersion"] = 2.5
        assertEquals("unrecognized_sync_snapshot", checkSnapshotEnvelopeAndChecksum(halfVersion).errorCode)
    }

    @Test
    fun `envelope rejects missing core lists`() {
        // [Dart抄录] :512-516（profiles/timeSchemes 必须是 List）
        val noProfiles = baseSnapshot(); noProfiles["profiles"] = "bad"
        assertEquals("missing_sync_timetable_data", checkSnapshotEnvelopeAndChecksum(noProfiles).errorCode)

        val noSchemes = baseSnapshot(); noSchemes["timeSchemes"] = 42L
        assertEquals("missing_sync_timetable_data", checkSnapshotEnvelopeAndChecksum(noSchemes).errorCode)
    }

    @Test
    fun `checksum mismatch fails and empty declaration skips verification`() {
        // [Dart抄录] :517-526
        // 1) 声明与重算不一致 → sync_snapshot_checksum_failed
        val tampered = baseSnapshot(); tampered["contentSha256"] = "deadbeef"
        val mismatch = checkSnapshotEnvelopeAndChecksum(tampered)
        assertEquals("sync_snapshot_checksum_failed", mismatch.errorCode)
        // 诊断字段：声明的 deadbeef 不可能等于重算值
        assertEquals("deadbeef", mismatch.expectedHash)
        assertEquals(64, mismatch.actualHash.length)
        assertTrue(mismatch.expectedHash != mismatch.actualHash)

        // 2) 声明空串 → 跳过校验（Dart expectedHash.isNotEmpty 才比对）
        val emptySha = baseSnapshot(); emptySha["contentSha256"] = ""
        assertTrue(checkSnapshotEnvelopeAndChecksum(emptySha).isValid)

        // 3) 正确哈希 → 通过
        val payload = LinkedHashMap(baseSnapshot())
        payload.remove("contentSha256")
        val good = baseSnapshot(); good["contentSha256"] = computeContentSha256(payload)
        assertTrue(checkSnapshotEnvelopeAndChecksum(good).isValid)
    }

    @Test
    fun `checksum ignores exportedAt and deviceId like content hash contract`() {
        // [Dart抄录] computeContentSha256 的排除键（C2）：同内容不同时刻导出哈希一致。
        // 门检查拿「去掉 contentSha256 的载荷」算哈希，所以 exportedAt/deviceId 改动
        // 不影响对账结果。
        val a = baseSnapshot(); a["contentSha256"] = ""
        val b = LinkedHashMap(a)
        b["exportedAt"] = "2030-01-01T00:00:00.000"
        b["deviceId"] = "other-device"
        assertTrue(checkSnapshotEnvelopeAndChecksum(a).isValid)
        assertTrue(checkSnapshotEnvelopeAndChecksum(b).isValid)
        assertEquals(
            checkSnapshotEnvelopeAndChecksum(a).actualHash,
            checkSnapshotEnvelopeAndChecksum(b).actualHash,
        )
    }

    // ---------- 宽松列表解析 ----------

    @Test
    fun `parseSnapshotStringList keeps non-empty strings only`() {
        // [Dart抄录] :270-273（whereType<String>().where(isNotEmpty)）
        assertEquals(
            listOf("张老师", "A101"),
            parseSnapshotStringList(listOf("张老师", "", 42, null, "A101")),
        )
        assertTrue(parseSnapshotStringList("bad").isEmpty())
        assertTrue(parseSnapshotStringList(null).isEmpty())
    }

    @Test
    fun `selectSnapshotMacros prefers warehouse list`() {
        // [Dart抄录] :275-281（warehouse.macros 是 List 优先，否则顶层 macros）
        val withWarehouse = linkedMapOf<String, Any?>(
            "warehouse" to linkedMapOf("macros" to listOf("wh-1")),
            "macros" to listOf("top-1"),
        )
        assertEquals(listOf<Any?>("wh-1"), selectSnapshotMacros(withWarehouse))

        val warehouseNotList = linkedMapOf<String, Any?>(
            "warehouse" to linkedMapOf<String, Any?>("macros" to "bad"),
            "macros" to listOf("top-1"),
        )
        assertEquals(listOf<Any?>("top-1"), selectSnapshotMacros(warehouseNotList))

        val onlyTop = linkedMapOf<String, Any?>("macros" to listOf("top-1"))
        assertEquals(listOf<Any?>("top-1"), selectSnapshotMacros(onlyTop))
    }

    @Test
    fun `parseOptionalSnapshotMaps drops malformed entries silently`() {
        // [Dart抄录] :283-300 + :417-483「parse snapshot skips malformed optional records」
        // 用 ScheduleDateRule.fromJson 当解析探针（core 依赖资产）。
        val good = linkedMapOf<String, Any?>(
            "id" to "rule-1", "name" to "夏令时", "timeSchemeId" to "scheme-1",
            "startDate" to "2026-05-01", "endDate" to "2026-09-30",
        )
        val raw: List<Any?> = listOf(42, "bad", null, good, linkedMapOf<String, Any?>("startDate" to ""))
        val result = parseOptionalSnapshotMaps(raw) {
            com.mutx163.qingyu.calendar.ScheduleDateRule.fromJson(it)
        }
        assertEquals(listOf(good), result.valid)
        assertEquals(5, result.rawCount)
        assertEquals(4, result.dropped)
        // 非 List 输入 → 空
        assertTrue(parseOptionalSnapshotMaps("bad") { it["x"].toString() }.valid.isEmpty())
    }

    @Test
    fun `optionalSnapshotString and normalized variants`() {
        // [Dart抄录] :684-690
        assertEquals("sig", optionalSnapshotString("sig"))
        assertNull(optionalSnapshotString(42))
        assertEquals("sig", normalizedOptionalSnapshotString("  sig  "))
        assertNull(normalizedSnapshotNullOrBlank("   "))
    }

    private fun normalizedSnapshotNullOrBlank(raw: Any?): String? = normalizedOptionalSnapshotString(raw)

    // ---------- exportedAt / deviceId 缺省 ----------

    @Test
    fun `snapshotExportedAtOrNow falls back to injected now`() {
        // [Dart抄录] :647-649（tryParse ?? DateTime.now()；now 供纯测试注入）
        assertEquals(
            "2026-03-22T09:00:00.000",
            snapshotExportedAtOrNow(linkedMapOf("exportedAt" to "2026-03-22T09:00:00.000")),
        )
        assertEquals("2000-01-01T00:00:00.000", snapshotExportedAtOrNow(emptyMap(), "2000-01-01T00:00:00.000"))
        // 解析失败同样回落
        assertEquals(
            "2000-01-01T00:00:00.000",
            snapshotExportedAtOrNow(linkedMapOf("exportedAt" to "bogus"), "2000-01-01T00:00:00.000"),
        )
    }

    @Test
    fun `snapshotDeviceIdOrEmpty defaults to empty string`() {
        // [Dart抄录] :650（?? ''）
        assertEquals("", snapshotDeviceIdOrEmpty(emptyMap()))
        assertEquals("d1", snapshotDeviceIdOrEmpty(linkedMapOf("deviceId" to "d1")))
        assertEquals("", snapshotDeviceIdOrEmpty(linkedMapOf("deviceId" to 42L)))
    }

    // ---------- meta 往返 ----------

    @Test
    fun `meta round trip preserves versioned body path`() {
        // [Dart抄录] app_sync_snapshot_service_test.dart:910-922
        val json = snapshotMetaToJson(
            exportedAtIso = "2026-07-05T12:00:00.000",
            contentSha256 = "hash-a",
            deviceId = "device-a",
            appVersion = "2.0.5",
            snapshotPath = "/Apps/qingyu-sync/snapshot-hash-a.mikcb",
        )
        val parsed = parseSnapshotMetaFields(json)
        assertTrue(parsed.isValid)
        assertEquals("hash-a", parsed.contentSha256)
        assertEquals("device-a", parsed.deviceId)
        assertEquals("2.0.5", parsed.appVersion)
        assertEquals("/Apps/qingyu-sync/snapshot-hash-a.mikcb", parsed.snapshotPath)
        assertEquals("2026-07-05T12:00:00.000", parsed.exportedAtIso)
    }

    @Test
    fun `meta rejects non-string fields and blanks snapshotPath`() {
        // [Dart抄录] :221-229（任一键非 null 非 String → invalid_sync_snapshot_meta）
        val bad = linkedMapOf<String, Any?>("contentSha256" to 42L)
        val parsed = parseSnapshotMetaFields(bad)
        assertFalse(parsed.isValid)
        assertEquals("invalid_sync_snapshot_meta", parsed.errorCode)

        // [Dart抄录] :217-218（snapshotPath 空白不写）
        val blankPath = snapshotMetaToJson(
            exportedAtIso = "2026-07-05T12:00:00.000",
            contentSha256 = "h",
            deviceId = "d",
            appVersion = null,
            snapshotPath = "  ",
        )
        assertFalse(blankPath.containsKey("snapshotPath"))
        assertFalse(blankPath.containsKey("appVersion"))
    }

    @Test
    fun `meta unparseable exportedAt falls back to epoch zero`() {
        // [Dart抄录] :232-233（tryParse ?? fromMillisecondsSinceEpoch(0)）
        val parsed = parseSnapshotMetaFields(linkedMapOf<String, Any?>("exportedAt" to "bogus"))
        assertTrue(parsed.isValid)
        // epoch 0 本地墙上时刻按系统时区换算，这里只钉「解不出 ≠ null」与 ISO 形态。
        assertTrue(Regex("""^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}$""").matches(parsed.exportedAtIso!!))
    }

    @Test
    fun `meta defaults missing hash and device to empty`() {
        // [Dart抄录] :234-235（?? ''）
        val parsed = parseSnapshotMetaFields(linkedMapOf())
        assertTrue(parsed.isValid)
        assertEquals("", parsed.contentSha256)
        assertEquals("", parsed.deviceId)
        assertNull(parsed.appVersion)
        assertNull(parsed.snapshotPath)
    }

    // ---------- warehouse 在场标记 ----------

    @Test
    fun `warehouse sections all present for own snapshots`() {
        // [Dart抄录] app_sync_snapshot_service_test.dart:955-963
        val warehouse = linkedMapOf<String, Any?>(
            "rememberedLogins" to emptyList<Any?>(),
            "customImportUrls" to emptyMap<String, Any?>(),
            "recentSchoolIds" to emptyList<Any?>(),
            "customDebugRecords" to emptyList<Any?>(),
        )
        assertEquals(
            setOf("rememberedLogins", "customImportUrls", "recentSchoolIds", "customDebugRecords"),
            snapshotWarehouseSectionPresence(warehouse),
        )
    }

    @Test
    fun `missing warehouse means no sections present`() {
        // [Dart抄录] :965-977（warehouse 整体缺失 / 非 Map → 四类全不在场）
        assertTrue(snapshotWarehouseSectionPresence(null).isEmpty())
        assertTrue(snapshotWarehouseSectionPresence("bad").isEmpty())
        assertTrue(snapshotWarehouseSectionPresence(42).isEmpty())
    }

    @Test
    fun `missing one warehouse key hides only that section`() {
        // [Dart抄录] :979-995（缺一个子键只影响该类别）
        val warehouse = linkedMapOf<String, Any?>(
            "rememberedLogins" to emptyList<Any?>(),
            "recentSchoolIds" to emptyList<Any?>(),
            "customDebugRecords" to emptyList<Any?>(),
            // customImportUrls 缺席
        )
        val sections = snapshotWarehouseSectionPresence(warehouse)
        assertFalse(sections.contains("customImportUrls"))
        assertTrue(sections.containsAll(setOf("rememberedLogins", "recentSchoolIds", "customDebugRecords")))
        // 键值为 null 也算「在场」（Dart containsKey 语义）
        val nullValue = linkedMapOf<String, Any?>("recentSchoolIds" to null)
        assertEquals(setOf("recentSchoolIds"), snapshotWarehouseSectionPresence(nullValue))
    }

    // ---------- 出厂默认作息判定 ----------

    @Test
    fun `factory default scheme matches by content not by id`() {
        // [Dart抄录] :180-194（逐段比 start/end，段数先决）
        val defaultScheme = TimeScheme(
            id = "scheme-1",
            name = "默认作息",
            sections = com.mutx163.qingyu.core.TimetableSettings.DEFAULT_SECTIONS,
            createdAt = java.time.LocalDateTime.of(2026, 7, 5, 12, 0),
            updatedAt = java.time.LocalDateTime.of(2026, 7, 5, 12, 0),
        )
        assertTrue(matchesFactoryDefaultTimeScheme(defaultScheme))

        // 段数不同 → false
        val fewer = defaultScheme.copy(sections = defaultScheme.sections.take(9))
        assertFalse(matchesFactoryDefaultTimeScheme(fewer))

        // 同段数但某段时间不同 → false
        val shifted = defaultScheme.copy(
            sections = defaultScheme.sections.mapIndexed { index, section ->
                if (index == 0) SectionTime("07:55", section.endTime) else section
            },
        )
        assertFalse(matchesFactoryDefaultTimeScheme(shifted))

        // 名称不同不影响判定（Dart 只比 sections）
        val renamed = defaultScheme.copy(name = "深度自定义")
        assertTrue(matchesFactoryDefaultTimeScheme(renamed))
    }

    // ---------- 咬合探针目标（探针细节见交付说明；此处为正向对照） ----------

    @Test
    fun `envelope constants align with sync snapshot contract`() {
        // [Dart抄录] app_sync_snapshot_service.dart:243-244 与 SNAPSHOT_* 常量同源
        assertEquals(2, SNAPSHOT_SCHEMA_VERSION)
        assertEquals("sync", SNAPSHOT_BACKUP_TYPE)
        assertEquals("mikcb", SNAPSHOT_APP_ID)
    }
}
