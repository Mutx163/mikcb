package com.mutx163.qingyu.platform

import java.io.File
import java.nio.file.Files
import org.junit.After
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * [LocalSnapshotStoreImpl] 的文件读写测试（纯 JVM，用临时目录）。
 *
 * 期望值人推：文件不存在 → null；写进去的字节逐位读回；空文件按「没有快照」；
 * 写完不留 `.tmp`；父目录缺失会自动建。
 */
class LocalSnapshotStoreImplTest {

    private val root: File = Files.createTempDirectory("mikcb-snapshot-test").toFile()

    @After
    fun tearDown() {
        root.deleteRecursively()
    }

    private fun store(file: File = File(root, LocalSnapshotStoreImpl.FILE_NAME)) =
        LocalSnapshotStoreImpl(file)

    @Test
    fun readSnapshotOnMissingFileReturnsNull() {
        assertNull(store().readSnapshot())
    }

    @Test
    fun writeThenReadRoundTripsBytesBitForBit() {
        val bytes = ByteArray(256) { it.toByte() }

        store().writeSnapshot(bytes)

        assertArrayEquals(bytes, store().readSnapshot())
    }

    @Test
    fun emptyFileIsTreatedAsNoSnapshot() {
        val file = File(root, LocalSnapshotStoreImpl.FILE_NAME)
        store(file).writeSnapshot(ByteArray(0))

        // 「写了个空文件」在语义上等于「没有本地快照」——否则备份会传一个 0 字节快照上去。
        assertNull(store(file).readSnapshot())
    }

    @Test
    fun writeLeavesNoTemporaryFileBehind() {
        val file = File(root, LocalSnapshotStoreImpl.FILE_NAME)

        store(file).writeSnapshot("payload".toByteArray())

        val leftovers = root.listFiles()!!.map { it.name }.filter { it.endsWith(".tmp") }
        assertTrue("不该留临时文件：$leftovers", leftovers.isEmpty())
        assertTrue(file.isFile)
    }

    @Test
    fun writeCreatesMissingParentDirectories() {
        val nested = File(File(root, "a/b"), LocalSnapshotStoreImpl.FILE_NAME)

        store(nested).writeSnapshot("x".toByteArray())

        assertArrayEquals("x".toByteArray(), store(nested).readSnapshot())
    }

    @Test
    fun overwritingReplacesPreviousContent() {
        val file = File(root, LocalSnapshotStoreImpl.FILE_NAME)
        store(file).writeSnapshot("first".toByteArray())

        store(file).writeSnapshot("second".toByteArray())

        assertArrayEquals("second".toByteArray(), store(file).readSnapshot())
        assertFalse(File(root, "${LocalSnapshotStoreImpl.FILE_NAME}.tmp").exists())
    }

    @Test
    fun fileNameMatchesTheDartConstant() {
        assertTrue(LocalSnapshotStoreImpl.FILE_NAME == "snapshot.mikcb")
    }
}
