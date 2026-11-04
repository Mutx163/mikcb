package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.sync.WebdavSyncConfig

/**
 * 云同步的**存储端口**（2026-11-04 从 `CloudSyncController` / `CloudSyncCoordinator` 搬出）。
 *
 * ## 为什么要单独一个文件
 *
 * 这两个接口是 `platform/` 生产实现的编译依赖（`WebdavConfigStoreImpl` /
 * `LocalSnapshotStoreImpl`）。它们原先是跟控制器/协调器定义在同一个文件里的，于是
 * **只想编译一个实现**就不得不把整个 `CloudSyncController.kt` 拉进来——而它 import
 * `pages/transfer`（L3 域）。`platform/` 的 3 个 JVM 单测（22 例）因此长期无法进 L0。
 *
 * 本文件只 import `sync/` 的纯数据类型，零 `android.*`、零 `pages/transfer`，
 * 所以 `platform/` 的纯 Kotlin 实现可以连同它一起独立进 JVM classpath。
 * 接口签名与包名保持不变（`com.mutx163.qingyu.pages.sync`），调用方无需改 import。
 */

/** 配置读写缝（生产用 SharedPreferences/加密存储，单测用内存实现）。密码也走这里。 */
interface WebdavConfigStore {
    fun loadConfig(): WebdavSyncConfig
    fun saveConfig(config: WebdavSyncConfig)
    fun hasStoredPassword(): Boolean
    fun storePassword(password: String)
    fun clearPassword()
}

/**
 * 本机快照读写接缝（生产用存储层实现，单测用内存假实现）。
 * 只读写「当前快照」这一份字节；多档案/任务写回归仓储（不在本层）。
 */
interface LocalSnapshotStore {
    fun readSnapshot(): ByteArray?
    fun writeSnapshot(bytes: ByteArray)
}
