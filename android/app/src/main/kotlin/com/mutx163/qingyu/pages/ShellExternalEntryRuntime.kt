package com.mutx163.qingyu.pages

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.mutx163.qingyu.pages.shell.ShellExternalEntry

/**
 * 外部入口的**进程级落点状态**（R1 切壳补口，2026-11-02）。
 *
 * 跳板 [ShellExternalEntryActivity] 解析外部 intent 后把结果 post 到这里；
 * 壳 [PagesShellActivity] 的组合树里只插一行 [ShellExternalEntryEffect] 消费——
 * 这是壳文件唯一需要的钩子（状态驱动，壳不读 intent、不写导航细节）。
 *
 * 为什么用 Compose 状态而不是 Flow/观察者：消费方就是壳的组合树，
 * `mutableStateOf` 让「跳板写 → 壳重组」这一步零胶水；跳板与壳同进程，
 * 跨 Activity 读同一份 snapshot state 没有问题。
 */
object ShellExternalEntryHub {

    /** 待推入的壳页面 id；null = 没有外部落点（落首页）。消费后置 null。 */
    var pendingPageId by mutableStateOf<String?>(null)
        private set

    /**
     * 待导入 payload（已在外部 URI 上读好）。由壳的导入页族消费；
     * 没有对应消费点时留在 hub（进程生命周期），下次进入对应页仍可用。
     */
    var pendingImport by mutableStateOf<ShellExternalEntry.ImportPayload?>(null)
        private set

    /** 跳板解析完成后调用：一次外部入口最多带一个落点 + 一份 payload。 */
    fun post(pageId: String?, payload: ShellExternalEntry.ImportPayload?) {
        pendingImport = payload ?: pendingImport
        pendingPageId = pageId
    }

    /** 壳组合里消费落点：取走并清空，返回 null 表示没有待处理入口。 */
    fun consumePageId(): String? {
        val id = pendingPageId
        pendingPageId = null
        return id
    }

    /** 导入页族消费 payload：取走并清空；[kind] 不符时不消费（留给对应页面）。 */
    fun consumeImport(kind: String): ShellExternalEntry.ImportPayload? {
        val payload = pendingImport ?: return null
        if (payloadKind(payload) != kind) return null
        pendingImport = null
        return payload
    }

    private fun payloadKind(payload: ShellExternalEntry.ImportPayload): String = when (payload) {
        is ShellExternalEntry.ImportPayload.Ics -> "ics"
        is ShellExternalEntry.ImportPayload.Backup -> "backup"
        is ShellExternalEntry.ImportPayload.Spreadsheet -> "spreadsheet"
        is ShellExternalEntry.ImportPayload.TooLarge -> ShellExternalEntry.IMPORT_KIND_TOO_LARGE
    }
}

/**
 * 壳里消费外部入口落点的**唯一钩子**（壳文件里只插这一行调用）。
 *
 * 观察 [ShellExternalEntryHub.pendingPageId]：跳板 post 后（无论壳是刚组合、
 * 还是已被 CLEAR_TOP+onNewIntent 复用），这里都会推一页。消费即清空，
 * 同一条入口不会重复触发。
 *
 * query 参数缺口（如实说明）：Flutter 版把深链的 query 一并交给 Dart；
 * 壳的导航只有页面 id，query 目前无消费方，深链映射不到页面时落首页。
 */
@Composable
fun ShellExternalEntryEffect(onOpenPage: (String) -> Unit) {
    val target by ShellExternalEntryHub.pendingPageId
    LaunchedEffect(target) {
        if (target == null) return@LaunchedEffect
        // 以消费那一刻的值为准（捕获值与消费之间若又 post 了新入口，推的是新值）。
        val pageId = ShellExternalEntryHub.consumePageId() ?: return@LaunchedEffect
        onOpenPage(pageId)
    }
}
