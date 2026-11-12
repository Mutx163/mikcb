package com.mutx163.qingyu.testutil

import java.io.File
import java.security.MessageDigest

/**
 * 「发版说明：真源 ↔ 进包镜像」一致性判据的**唯一实现**（2026-11-12 抽取）。
 *
 * 真源是仓库根的 `docs/releases/v*.md`；进包的是 `android/app/src/main/assets/docs/releases/`
 * 那份**手工**拷贝——历史上没有任何自动化，一律人工提交同步。
 *
 * ## 为什么抽到 testutil
 *
 * 这段判据原先只活在 `pages/about/FlutterAssetsDecouplingGuardTest.kt` 里，只有全量 L2 才会跑到；
 * `2026-11-12` 的 `9b10a1b1d`（改真源没同步镜像）就是排到 L2 末尾、2 分多钟才暴露。
 * 抽成共享函数后，crossguard 的 L0 入口用**同一个函数**做秒级同口径判定；
 * 两份各写一份的话，改了一边另一边会悄悄漂，而且「哪份算准」没有答案。
 *
 * ## 判什么
 *
 * 1. **清单相等**：真源多一个（漏拷，应用内会缺该版本）或镜像多一个（真源删了没跟着删）都算问题；
 * 2. **同名文件内容一致**：比「换行规范化后」的哈希，避免 `core.autocrlf` 下 LF/CRLF 误红。
 *
 * 真源里另外三份内部文档（`3.0.0-1-hard-gates.md` / `-release-runbook.md` /
 * `-upgrade-checklist.md`）**不进包**，按 [RELEASE_NOTE_NAME] 过滤，不参与对拍。
 * 有意新增/废弃版本时，改的是 `docs/releases/` 与镜像两处，判据与测试都不需要动。
 */
fun releaseNotesMirrorProblems(sourceDir: File, mirrorDir: File): List<String> {
    val problems = mutableListOf<String>()
    if (!sourceDir.isDirectory) {
        problems += "读不到更新日志真源目录：${sourceDir.path}"
        return problems
    }
    if (!mirrorDir.isDirectory) {
        problems += "读不到更新日志镜像目录：${mirrorDir.path}"
        return problems
    }

    val sourceNames = sourceDir.listFiles()
        ?.filter { it.isFile && RELEASE_NOTE_NAME.matches(it.name) }
        ?.map { it.name }
        ?.sorted()
        ?: emptyList()
    val mirrorNames = mirrorDir.listFiles()
        ?.filter { it.isFile }
        ?.map { it.name }
        ?.sorted()
        ?: emptyList()

    if (sourceNames.isEmpty()) {
        problems += "docs/releases 里一份 v*.md 都没有（真源被清空了？）：${sourceDir.path}"
    }

    val missing = sourceNames - mirrorNames.toSet()
    val orphan = mirrorNames - sourceNames.toSet()
    if (missing.isNotEmpty() || orphan.isNotEmpty()) {
        problems += "更新日志镜像与 docs/releases 清单不一致。" +
            "漏拷（应用内会缺这些版本）：$missing；" +
            "镜像孤儿文件（真源已没有）：$orphan。" +
            "手工同步：cp docs/releases/v*.md android/app/src/main/assets/docs/releases/"
    }

    // 只在**两侧都存在**的文件上比内容：漏拷时若照样去读镜像侧，
    // 会先撞 FileNotFoundException，报错从「漏拷清单」变成一句栈，反而说不清问题。
    val mirrored = mirrorNames.toSet()
    val stale = sourceNames.filter { name ->
        name in mirrored &&
            normalizedTextHash(File(sourceDir, name)) != normalizedTextHash(File(mirrorDir, name))
    }
    if (stale.isNotEmpty()) {
        problems += "以下更新日志在两个目录内容不一致（手工同步时漏更新正文）：$stale"
    }
    return problems
}

/** 真源里「给 App 看的发版说明」的文件名形态（`v1.1.10.6.md` / `v1.1.5.a.md`）。 */
val RELEASE_NOTE_NAME = Regex("""^v\d[\w.\-]*\.md$""")

/** 文本资产按「换行规范化后」取哈希，与检出方式的 CRLF/LF 无关。 */
fun normalizedTextHash(file: File): String {
    val text = file.readText().replace("\r\n", "\n").replace("\r", "\n")
    return sha256Hex(text.toByteArray(Charsets.UTF_8))
}

/** SHA-256 的小写十六进制串。 */
fun sha256Hex(bytes: ByteArray): String =
    MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }
