package com.mutx163.qingyu.platform

import com.mutx163.qingyu.pages.sync.LocalSnapshotStore
import java.io.File
import java.io.IOException

/**
 * [LocalSnapshotStore] 的**生产实现**：应用私有目录下的一个快照文件。
 *
 * 纯 Kotlin（只碰 `java.io.File`），所以能在 JVM 单测里跑；Android 侧由
 * [AppLocalSnapshotStore] 把 `filesDir` 传进来。
 *
 * ## 与 Dart 的关系（去核过）
 *
 * **Dart 没有「本机快照文件」这个东西**：它的下载结果是直接写进 prefs / 仓储
 * （`timetable_profiles` 等），只有**远端**路径用 `snapshotFileName = 'snapshot.mikcb'`
 * （`webdav_sync_config.dart:42` 只用于拼 `snapshotRemotePath`）。
 * 所以这一层是 **Compose 侧新增的缝**，不是「照抄 Dart 口径」——文件名沿用同一个常量，
 * 免得以后真出现本地快照时两个名字打架。
 *
 * ## ⚠️ 调用方义务（这条不做，用户点「立即备份」会看到失败）
 *
 * `WebdavSyncCoordinator` 上传的是 [readSnapshot] 返回的字节。本类只是**存放点**，
 * **不会自己去序列化仓储**。宿主必须在「备份前」把当前数据的快照字节写进来
 * （或在本地数据变化后随时刷新），否则 `readSnapshot()` 返回 null，界面按
 * 「本地快照缺失」失败。认领文件 C1 的真机对照清单里把这条写成了前置条件。
 *
 * ## 写是「临时文件 + rename」的原子替换
 *
 * 直接覆盖写会在写到一半被杀时留下**半截快照**——下次备份就把它当成本地数据上传，
 * 云端多一份坏快照。先写 `.tmp` 再 rename（同目录内 rename 是原子的）可以避免。
 */
class LocalSnapshotStoreImpl(private val file: File) : LocalSnapshotStore {

    override fun readSnapshot(): ByteArray? {
        if (!file.isFile) return null
        return try {
            file.readBytes().takeIf { it.isNotEmpty() }
        } catch (_: IOException) {
            // 读不动（权限/IO）按「没有本地快照」处理，由界面提示重新生成。
            null
        } catch (_: SecurityException) {
            null
        }
    }

    override fun writeSnapshot(bytes: ByteArray) {
        val parent = file.parentFile
        parent?.mkdirs()
        val tmp = File(parent, "${file.name}.tmp")
        tmp.writeBytes(bytes)
        if (!tmp.renameTo(file)) {
            // 少数文件系统上 rename 会失败（目标存在/跨卷）：退回直接写并清掉临时文件。
            file.writeBytes(bytes)
            tmp.delete()
        }
    }

    companion object {
        /** 与 Dart `WebdavSyncConfig.SNAPSHOT_FILE_NAME` 逐字一致。 */
        const val FILE_NAME = "snapshot.mikcb"
    }
}
