package com.mutx163.qingyu.share

/**
 * 「数据备份与迁移」页 `.mikcb` 传输包的**系统分享 / 选文件契约**（纯 Kotlin，零 `android.*` 依赖）。
 *
 * ## 为什么单独抽一层
 *
 * `.mikcb` 的真导出/真导入要落两端 Android 胶水：
 * `platform/AndroidTransferShareAdapter`（写缓存 → `FileProvider` → 系统分享面板）与
 * `platform/AndroidTransferDocumentAdapter`（`ACTION_OPEN_DOCUMENT` → 限长读文本）。
 * 那两个类引 `android.*`，**进不了 JVM 单测 classpath**（`scripts/test-kotlin-module.ps1`
 * 的纯 Kotlin 判定是整目录的，见该脚本「跳过共享目录」一段）。一旦 authority、缓存目录名、
 * MIME、字节上限这些「一改就静默坏掉」的字符串散落在适配器里，就没有任何自动化测试能钉住它们。
 *
 * 所以判据全部放这里，适配器只照单执行、**不自己拍字符串**。同一套路与本仓既有的
 * `pages/export/IcsShareLogic`（ICS 分享）、`pages/sync/BackupSafContract`（备份 SAF）一致。
 *
 * ## 跨层必须逐字一致的三处（改一个就要同步改另外两个）
 *
 * 1. [PROVIDER_AUTHORITY_SUFFIX] ↔ `AndroidManifest.xml` 里
 *    `<provider android:authorities="${applicationId}.fileprovider">`；
 * 2. [PROVIDER_PATH_NAME] / [CACHE_DIR_NAME] ↔ `res/xml/file_paths.xml` 里
 *    `<cache-path name="transfer_share" path="transfer-share/"/>`；
 * 3. [EXTENSION] ↔ `pages/transfer/DataTransferLogic.FILE_EXTENSION`（本层不能反向依赖 `pages/`，
 *    只能靠这条注释 + 各侧单测对拍；两处都必须是 `"mikcb"`）。
 *
 * 第 1、2 条是本批交付里**最容易「代码全对、运行必炸」**的地方：provider 没注册
 * ⇒ `FileProvider.getUriForFile` 抛 `IllegalArgumentException` ⇒ 适配器返回
 * [Failure.PROVIDER_UNAVAILABLE]；注册了但 xml 没覆盖这个子目录 ⇒ 同样 `IllegalArgumentException`。
 */
object TransferShareContract {

    /**
     * `.mikcb` 包体是 UTF-8 JSON 文本（与 Dart 侧 `UnifiedTransferService` 打出的包一致），
     * 分享时用它当 `Intent.setType`：接收方多半只对文本类（`text/…`）或 `application/json`
     * 给「存成文本」之类的入口，用 `application/octet-stream` 会掉到「其他」一档。
     */
    const val MIME_JSON: String = "application/json"

    /** 未知扩展名在系统里通常落到这个类型；选文件时作为兜底候选，保证 `.mikcb` 能被选中。 */
    const val MIME_BINARY: String = "application/octet-stream"

    /** authority 后缀；与 manifest 的 `${applicationId}.fileprovider` 同一口径。 */
    const val PROVIDER_AUTHORITY_SUFFIX: String = ".fileprovider"

    /** 写分享文件的子目录名（相对 `context.cacheDir`）——**不能**带斜杠，见 [providerCacheRelativePath]。 */
    const val CACHE_DIR_NAME: String = "transfer-share"

    /**
     * `res/xml/file_paths.xml` 里 `<cache-path name="…">` 的 name。
     *
     * 它决定 content Uri 的第一段路径（`content://<authority>/transfer_share/<文件名>`），
     * 所以**不是**目录名：目录名是 [CACHE_DIR_NAME]（带连字符），这个（带下划线）只是 Uri 里的
     * 别名。两者必须分别与 xml 的 `name=` / `path=` 逐字一致。
     */
    const val PROVIDER_PATH_NAME: String = "transfer_share"

    /**
     * 导入时允许的最大文件字节数 = 20 MiB。
     *
     * 与 Dart 侧 `UnifiedTransferService.maxImportFileBytes`（`20 * 1024 * 1024`）同值，
     * 语义也同：真实导出包是未压缩的课表 JSON，正常只有几百 KB～2 MB 量级，这个上限
     * 不是为了「判对错」，而是**在把字节读进内存之前**拒掉荒谬的大文件
     * （Android 上 OOM 是杀进程，不是可捕获异常，见 `lib/utils/import_file_reader.dart` 注释）。
     */
    const val MAX_IMPORT_BYTES: Int = 20 * 1024 * 1024

    /** 传输包扩展名（不带点）。 */
    const val EXTENSION: String = "mikcb"

    /**
     * 系统文件选择器要的 MIME 候选：`.json` 与 `.mikcb` 都要能被选中。
     *
     * **顺序是契约的一部分**（单测钉住）：`application/json` 在前——放到 `EXTRA_MIME_TYPES`
     * 数组里时，部分 Rom 的选择器会把首项当成默认过滤档，先给最常见的 JSON 更不容易空列表。
     * 与 `pages/sync/BackupSafContract.OPEN_MIME_TYPES`（同为 JSON 在前）保持一致口径。
     */
    val OPEN_MIME_TYPES: List<String> = listOf(MIME_JSON, MIME_BINARY)

    /**
     * FileProvider authority = `<applicationId>.fileprovider`。
     *
     * 必须用运行期 applicationId 而不是包名常量：本仓 `dev` / `perf` / `itest` 三个变体带
     * `applicationIdSuffix`（`.debug` / `.profile` / `.itest`），manifest 的 `${applicationId}`
     * 会跟着变，写死 `com.mutx163.qingyu.fileprovider` 只有正式包能分享出去。
     * 适配器的 `applicationId` 默认取 `context.packageName`，运行期正好是当前变体的 applicationId。
     *
     * 空值直接拒绝：否则会静默拼出 `.fileprovider` 这种永远匹配不上的 authority，
     * 排障时会呈现成「分享按钮没反应」。
     */
    fun providerAuthority(applicationId: String): String {
        val trimmed = applicationId.trim()
        require(trimmed.isNotEmpty()) {
            "applicationId 不能为空：FileProvider authority 由它派生"
        }
        return trimmed + PROVIDER_AUTHORITY_SUFFIX
    }

    /**
     * 文件相对 `cacheDir` 的路径，形如 `transfer-share/xxx.mikcb`。
     *
     * 适配器据此 `File(context.cacheDir, 返回值)` 落盘；必须落在 [CACHE_DIR_NAME] 下，
     * 因为 `file_paths.xml` 只把那个目录（`<cache-path path="transfer-share/">`）授给 FileProvider，
     * 落到别处 `getUriForFile` 会直接抛 `IllegalArgumentException`。
     */
    fun providerCacheRelativePath(fileName: String): String = "$CACHE_DIR_NAME/$fileName"

    /**
     * 限长判断：**超过**上限才算超。
     *
     * 边界口径与 Dart `readImportFileBytes`（`if (length > maxBytes) throw`）逐字一致：
     * 恰好等于 [maxBytes] 的文件**可以导入**（不超），只多 1 字节就拒。
     * 用 `Long` 收尺寸是因为 `OpenableColumns.SIZE` 与 `File.length()` 都是 `Long`，
     * 在 `Int` 上比会先溢出再比较。
     */
    fun exceedsLimit(sizeBytes: Long, maxBytes: Int = MAX_IMPORT_BYTES): Boolean =
        sizeBytes > maxBytes.toLong()

    /**
     * 导出/导入失败分类 → **屏上文案键**（返回 ARB 键名，不返回中文）。
     *
     * 返回键名而不是成品中文，是为了让文案能跟 ARB 逐字对拍：界面层拿这个键去查
     * `AppLocalizations`，键改了这里单测会红，而不是界面上悄悄多出一句没翻译的英文。
     *
     * **诚实边界**：`FILE_TOO_LARGE` / `READ_FAILED` 复用 Dart 侧既有键
     * （`importFileTooLarge` / `importFileReadFailed`，六个 ARB 里都有现成译文）。
     * 导出侧三类失败（写盘 / provider 不可用 / 没有目标应用 / 拉起失败）在现有 ARB 里
     * **没有专属键**，统一落到通用 `saveFailed`（「保存失败」）——不在这里自造一个
     * 不存在的键，否则界面会渲染成空白或英文 key。补专属文案属 Lead 的 ARB 范围，
     * 补完后只改本函数这一处。
     *
     * ⚠️ `importFileTooLarge` 在 ARB 里带 `{size}` 占位符，界面填参时用
     * `MAX_IMPORT_BYTES` 对应的人话预算（当前即 `20 MB`），不要留空。
     */
    fun failureMessageKey(failure: Failure): String = when (failure) {
        Failure.FILE_TOO_LARGE -> "importFileTooLarge"
        Failure.READ_FAILED -> "importFileReadFailed"
        Failure.WRITE_FAILED -> "saveFailed"
        Failure.PROVIDER_UNAVAILABLE -> "saveFailed"
        Failure.NO_TARGET -> "saveFailed"
        Failure.LAUNCH_FAILED -> "saveFailed"
    }

    /**
     * 失败分类。**分类存在**的目的是排障与差异化文案，不是把异常吞成一句「失败」：
     * 适配器永远返回具体某一项，绝不 `catch (Exception)` 后统一回一个含糊结果。
     */
    enum class Failure {

        /** 缓存文件写不进去（磁盘满、目录被删、`SecurityException`）。 */
        WRITE_FAILED,

        /**
         * `FileProvider.getUriForFile` 抛 `IllegalArgumentException`：manifest 里没注册 provider
         * （**本仓当前状态**，注册属 Lead），或 `file_paths.xml` 没覆盖 [CACHE_DIR_NAME]。
         */
        PROVIDER_UNAVAILABLE,

        /** 没有能接这个 Intent 的应用（`ActivityNotFoundException`，或选择器本身解析不到）。 */
        NO_TARGET,

        /** 系统拒绝拉起（`SecurityException` 等非「无目标」的启动失败）。 */
        LAUNCH_FAILED,

        /** 读用户选中的文件失败（打不开流、provider 已失效、解码后为空）。 */
        READ_FAILED,

        /** 文件字节数超上限（**读完之前**就判下来了，不会把超大文件读进内存）。 */
        FILE_TOO_LARGE,
    }
}
