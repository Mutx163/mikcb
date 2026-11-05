package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.Course
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 恢复成功被宏导入失败**翻转成失败**的回归守卫（2026-11-05 数据安全修复）。
 *
 * 修复前：`applySnapshot` 里 `restoreFromCloudSnapshot` 成功后紧接
 * `applyWarehouseMacros?.invoke(...)`，两者同在一个 try——宏回调抛错会让整次恢复
 * 返回 `Failed`，但课表其实已经落盘。调用方据此走「恢复失败」分支
 * （提示重试 / 回滚决策全部错位：重试等于把同一份课表再恢复一遍）。
 *
 * 守卫钉两件事，且**断言的是落盘结果而不是只看返回值**：
 * 1. 宏回调抛错 ⇒ 返回仍是 [SnapshotApplyResult.Applied]；
 * 2. 磁盘上 profiles 已是快照内容（远端课程在、本地旧课不在）。
 *
 * 咬合探针（2026-11-05 实测）：把桥里宏调用的独立 try 拿掉（异常直穿外层 catch）→
 * 本用例变红（返回变成 Failed）→ 还原后绿。
 */
class TimetableSnapshotBridgeMacroFailureTest {

    private fun course(id: String): Course = Course(
        id = id,
        name = "课程-$id",
        teacher = "",
        location = "",
        dayOfWeek = 1,
        startSection = 1,
        endSection = 2,
        startTime = "08:00",
        endTime = "09:40",
    )

    private fun snapshotBytes(macros: List<Map<String, Any?>>): ByteArray {
        val remote = TimetableRepository(TimetableStore(InMemoryKeyValueStore()))
        remote.addCourse(course("remote"))
        val result = TimetableSnapshotBridge.buildSnapshotBytes(
            repository = remote,
            deviceId = "devB",
            exportedAtIso = "2026-03-06T08:00:00.000",
            macros = macros,
        )
        assertTrue("快照应构建成功", result is SnapshotBuildResult.Success)
        return (result as SnapshotBuildResult.Success).bytes
    }

    @Test
    fun `宏导入抛错_返回仍是 Applied 且课表确实已落盘`() {
        val bytes = snapshotBytes(listOf(linkedMapOf("schoolId" to "s1", "adapterId" to "a1")))
        val delegate = InMemoryKeyValueStore()
        val store = TimetableStore(delegate)
        val local = TimetableRepository(store)
        local.addCourse(course("local"))

        val result = TimetableSnapshotBridge.applySnapshot(local, bytes) {
            error("injected macro import failure")
        }

        assertTrue(
            "恢复成功不该被宏导入失败翻转（课表已落盘，报 Failed 会让调用方重试/回滚全部错位）",
            result is SnapshotApplyResult.Applied,
        )
        // —— 落盘断言：磁盘 profiles 已是快照内容 ——
        val raw = delegate.getString(TimetableStore.KEY_PROFILES).orEmpty()
        assertTrue("磁盘应已恢复远端课程（course id=remote 进了 profiles JSON）", raw.contains("\"remote\""))
        assertFalse("本地旧课程不应残留（整份覆盖语义）", raw.contains("\"local\""))
        assertEquals(
            "内存快照应与磁盘一致（恢复成功路径的既有语义）",
            listOf("remote"),
            local.snapshot.courses.map { it.id },
        )
    }
}
