package com.mutx163.qingyu.platform

import android.content.Context
import com.mutx163.qingyu.pages.sync.LocalSnapshotStore
import java.io.File

/**
 * Android 胶水：把纯 Kotlin 的 [LocalSnapshotStoreImpl] 绑到应用私有目录
 * （`filesDir/snapshot.mikcb`）。
 *
 * 单独一个文件是为了让 [LocalSnapshotStoreImpl] 保持纯 Kotlin——它能进 JVM 单测，
 * 这个文件只能靠真机/编译验证。
 */
class AppLocalSnapshotStore(context: Context) :
    LocalSnapshotStore by LocalSnapshotStoreImpl(
        File(context.filesDir, LocalSnapshotStoreImpl.FILE_NAME),
    )
