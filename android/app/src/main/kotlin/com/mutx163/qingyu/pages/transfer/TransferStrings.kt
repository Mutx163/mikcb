package com.mutx163.qingyu.pages.transfer

/**
 * 数据备份与迁移 / 二维码传输模块用到的 ARB 文案（`lib/l10n/app_zh.arb`，模板语言 zh）。
 *
 * **逐字抄录，不许改写**：每一条都在 [TransferStringsParityTest] 里与 ARB 机械比对，
 * 键缺失或值被改写都会红。要改界面文字，先改 ARB（六份同步）+ 重新生成 `gen-l10n`，
 * 再同步这里。
 *
 * 键名与 ARB 键逐字一致，便于 `grep` 双向核对。
 */
typealias ArbText = com.mutx163.qingyu.app.ArbText

object TransferStrings {

    // ── 数据备份与迁移页 ──
    val dataTransferEntryTitle = ArbText("dataTransferEntryTitle", "数据备份与迁移")
    val dataTransferEntrySubtitle =
        ArbText("dataTransferEntrySubtitle", "导出完整课表文件，给别人直接导入使用")
    val dataTransferTitle = ArbText("dataTransferTitle", "数据备份与迁移")
    val timetableAppName = ArbText("timetableAppName", "轻屿课表")

    // ── 完整导出 ──
    val fullExportTitle = ArbText("fullExportTitle", "完整导出")
    val fullExportSubtitle = ArbText(
        "fullExportSubtitle",
        "支持导出当前课表，或一次导出全部课表、时间模板和当前选中状态",
    )
    val exportCurrentTimetable = ArbText("exportCurrentTimetable", "导出当前课表")
    val exportAllData = ArbText("exportAllData", "导出全部数据")
    val exportTimeTemplate = ArbText("exportTimeTemplate", "导出时间模板")

    // ── 完整导入 ──
    val fullImportTitle = ArbText("fullImportTitle", "完整导入")
    val fullImportSubtitle = ArbText(
        "fullImportSubtitle",
        "导入时可以选择覆盖当前课表，或直接导入为一个新课表，建议先导出自己的备份",
    )
    val chooseFileAndImport = ArbText("chooseFileAndImport", "选择文件并导入")

    // ── 分享文案 ──
    val dataTransferProfileShareText =
        ArbText("dataTransferProfileShareText", "这是轻屿课表当前课表的完整备份文件，导入后可直接恢复课程和设置")
    val dataTransferProfileShareSubject =
        ArbText("dataTransferProfileShareSubject", "轻屿课表备份")
    val dataTransferProfileShareSubjectNamed =
        ArbText("dataTransferProfileShareSubjectNamed", "{profileName} - 轻屿课表备份")
    val dataTransferFullBackupShareText = ArbText(
        "dataTransferFullBackupShareText",
        "这是轻屿课表的全部数据备份文件，包含所有课表、当前选中课表和时间模板",
    )
    val dataTransferFullBackupShareSubject =
        ArbText("dataTransferFullBackupShareSubject", "轻屿课表 - 全部数据备份")
    val dataTransferTimeSchemeShareText =
        ArbText("dataTransferTimeSchemeShareText", "这是轻屿课表的时间模板分享文件，导入后即可恢复使用")
    val timeSchemeShareSubject = ArbText("timeSchemeShareSubject", "轻屿课表 · 时间模板")

    // ── 二维码面对面传输 ──
    val qrTransferSectionTitle = ArbText("qrTransferSectionTitle", "二维码面对面传输")
    val qrTransferSectionSubtitle = ArbText(
        "qrTransferSectionSubtitle",
        "两台手机靠近，扫码即可直接传输课表与全部设置，无需网络",
    )
    val qrTransferSendCurrent = ArbText("qrTransferSendCurrent", "二维码发送当前课表")
    val qrTransferSendAll = ArbText("qrTransferSendAll", "二维码发送全部数据")
    val qrTransferScanReceive = ArbText("qrTransferScanReceive", "扫码接收课表数据")
    val qrTransferPlaintextWarning = ArbText(
        "qrTransferPlaintextWarning",
        "二维码传输是明文，附近摄像头可能读取内容。请确认来源，未经确认不会覆盖数据。",
    )
    val qrTransferShareWeek = ArbText("qrTransferShareWeek", "分享本周课表")
    val qrTransferShareSelectedCourses = ArbText("qrTransferShareSelectedCourses", "分享勾选的课程")
    val qrTransferShareTimeTemplate = ArbText("qrTransferShareTimeTemplate", "分享时间模板")
    val qrTransferSelectCoursesDone = ArbText("qrTransferSelectCoursesDone", "完成")
    val noCoursesInCurrentProfile = ArbText("noCoursesInCurrentProfile", "当前课表已经没有课程")

    // ── 二维码发送/接收页 ──
    val qrTransferFrameProgress = ArbText("qrTransferFrameProgress", "已发送 {sent} 帧，约需 {total} 帧")
    val qrTransferSendHint = ArbText("qrTransferSendHint", "请对方打开扫码接收并对准屏幕，保持直到传输完成")
    val qrTransferStop = ArbText("qrTransferStop", "停止发送")
    val qrTransferScanTitle = ArbText("qrTransferScanTitle", "扫码接收")
    val qrTransferScanHint = ArbText("qrTransferScanHint", "将摄像头对准对方手机屏幕，保持稳定，等待进度完成")
    val qrTransferCameraUnavailable =
        ArbText("qrTransferCameraUnavailable", "相机不可用，请检查是否被其他应用占用")
    val qrTransferCameraRetry = ArbText("qrTransferCameraRetry", "重试")
    val qrTransferReceiveProgress =
        ArbText("qrTransferReceiveProgress", "已接收 {received} 帧 · 已解出 {decoded}/{total}")
    val qrTransferReceiveComplete = ArbText("qrTransferReceiveComplete", "数据接收完成，正在导入……")
    val qrTransferRestart = ArbText("qrTransferRestart", "重新开始")
    val qrTransferSampleFps = ArbText("qrTransferSampleFps", "采样帧率")
    val qrTransferDecodeFps = ArbText("qrTransferDecodeFps", "解码帧率")
    val qrTransferReceiveSpeed = ArbText("qrTransferReceiveSpeed", "接收速度")
    val qrTransferElapsed = ArbText("qrTransferElapsed", "已用时间")
    val qrTransferNewFrames = ArbText("qrTransferNewFrames", "新增帧")
    val qrTransferDuplicateFrames = ArbText("qrTransferDuplicateFrames", "重复帧")
    val qrTransferBlockSize = ArbText("qrTransferBlockSize", "单块大小")
    val qrTransferBlockCount = ArbText("qrTransferBlockCount", "数据块数")
    val qrTransferFileData = ArbText("qrTransferFileData", "文件数据")
    val qrTransferFileDataDetail =
        ArbText("qrTransferFileDataDetail", "原始 {rawSize} · 压缩 {compressedSize}")

    // ── 二维码失败提示 ──
    val qrTransferSessionMismatch =
        ArbText("qrTransferSessionMismatch", "检测到不同传输内容，请确认只对准一份数据")
    val qrTransferChecksumFailed = ArbText("qrTransferChecksumFailed", "传输校验失败，请重新开始")
    val qrTransferRawLengthMismatch =
        ArbText("qrTransferRawLengthMismatch", "接收数据长度校验失败，请重新开始")
    val qrTransferDecompressionFailed =
        ArbText("qrTransferDecompressionFailed", "数据解压失败，请重新开始")
    val qrTransferResourceLimit = ArbText(
        "qrTransferResourceLimit",
        "接收数据超过二维码传输资源上限，请重新开始并使用更小的备份。",
    )
    val qrTransferSessionExpired =
        ArbText("qrTransferSessionExpired", "二维码传输已超时，请重新开始并只对准一台设备。")
    val qrTransferDecodeFailed = ArbText("qrTransferDecodeFailed", "二维码数据解码失败，请重新开始")
    val qrTransferFullBackupWarning =
        ArbText("qrTransferFullBackupWarning", "确认后，该完整备份会替换本设备上的数据。")
    val qrTransferImportFullBackup = ArbText("qrTransferImportFullBackup", "导入完整备份")

    // ── 概览 ──
    val transferOverviewTitle = ArbText("transferOverviewTitle", "当前可迁移内容")
    val courseCountBullet = ArbText("courseCountBullet", "课程数量：{count} 门")
    val currentTimetableBullet = ArbText("currentTimetableBullet", "当前课表：{name}")
    val allTimetablesBullet = ArbText("allTimetablesBullet", "全部课表：{count} 个")
    val timeSchemeCountBullet = ArbText("timeSchemeCountBullet", "时间模板：{count} 套")
    val currentWeekBullet = ArbText("currentWeekBullet", "当前周：第 {week} 周")
    val semesterStartUnsetBullet = ArbText("semesterStartUnsetBullet", "开学日期：未设置")
    val semesterStartBullet = ArbText("semesterStartBullet", "开学日期：{date}")
    val fileExtensionBullet = ArbText("fileExtensionBullet", "文件后缀：.{extension}")

    // ── 导入结果与预览弹窗 ──
    val dataTransferUndoSuccess = ArbText("dataTransferUndoSuccess", "已撤销本次导入")
    val dataTransferUndoFailed = ArbText("dataTransferUndoFailed", "撤销失败")
    val selectImportModeTitle = ArbText("selectImportModeTitle", "选择导入方式")
    val selectImportModeMessage =
        ArbText("selectImportModeMessage", "你可以覆盖当前课表，或者把备份导入成一个新的独立课表")
    val selectImportModeMerge = ArbText("selectImportModeMerge", "合并更改")
    val replaceCurrentTimetable = ArbText("replaceCurrentTimetable", "覆盖当前课表")
    val importAsNewTimetable = ArbText("importAsNewTimetable", "导入为新课表")
    val createdNewTimetableAfterImport =
        ArbText("createdNewTimetableAfterImport", "导入成功，已创建新的课表")

    /**
     * 「导入为新课表」用的默认档名（包内没带课表名时）。
     *
     * 发布版这条是**硬编码字面量** `'导入课表'`（`timetable_import_export_service.dart:780` 工作区），
     * 本仓不许新增硬编码中文（`CjkLiteralGateTest`），所以走文案系统；值与发布版逐字相同。
     */
    val transferImportedProfileName = ArbText("transferImportedProfileName", "导入课表")

    /**
     * 「导入为新课表」建新档时，若包里没有可用模板、需要新建一套时用的模板名：
     * `<课表名> 时间`（发布版硬编码 `'$nextName 时间'`，语义与用词照抄）。
     */
    val transferImportedTimeSchemeName =
        ArbText("transferImportedTimeSchemeName", "{name} 时间")
    val backupRestoredSuccess = ArbText("backupRestoredSuccess", "导入成功，备份数据已恢复")
    val importFailedInvalidFile = ArbText("importFailedInvalidFile", "导入失败，请确认文件有效")
    val importFileReadFailed = ArbText("importFileReadFailed", "无法读取所选文件")
    val importFileTooLarge = ArbText("importFileTooLarge", "文件超出大小上限 {size}，请选择较小的文件")
    val importPartialSkippedSuffix = ArbText("importPartialSkippedSuffix", "，其中 {count} 条格式损坏已跳过")
    val coursesBeyondSchemeExtraSuffix = ArbText(
        "coursesBeyondSchemeExtraSuffix",
        "，另有 {count} 节超出当前作息范围 共 {sections} 节，课表暂不显示",
    )
    val sendFailedWithError = ArbText("sendFailedWithError", "发送失败：{error}")

    // ── 通用 ──
    val themeUndo = ArbText("themeUndo", "撤销")
    val cancelAction = ArbText("cancelAction", "取消")

    /** 全部上屏文案（`TransferStringsParityTest` 逐条与 ARB 对拍）。 */
    val allTexts: List<ArbText> = listOf(
        dataTransferEntryTitle,
        dataTransferEntrySubtitle,
        dataTransferTitle,
        timetableAppName,
        fullExportTitle,
        fullExportSubtitle,
        exportCurrentTimetable,
        exportAllData,
        exportTimeTemplate,
        fullImportTitle,
        fullImportSubtitle,
        chooseFileAndImport,
        dataTransferProfileShareText,
        dataTransferProfileShareSubject,
        dataTransferProfileShareSubjectNamed,
        dataTransferFullBackupShareText,
        dataTransferFullBackupShareSubject,
        dataTransferTimeSchemeShareText,
        timeSchemeShareSubject,
        qrTransferSectionTitle,
        qrTransferSectionSubtitle,
        qrTransferSendCurrent,
        qrTransferSendAll,
        qrTransferScanReceive,
        qrTransferPlaintextWarning,
        qrTransferShareWeek,
        qrTransferShareSelectedCourses,
        qrTransferShareTimeTemplate,
        qrTransferSelectCoursesDone,
        noCoursesInCurrentProfile,
        qrTransferFrameProgress,
        qrTransferSendHint,
        qrTransferStop,
        qrTransferScanTitle,
        qrTransferScanHint,
        qrTransferCameraUnavailable,
        qrTransferCameraRetry,
        qrTransferReceiveProgress,
        qrTransferReceiveComplete,
        qrTransferRestart,
        qrTransferSampleFps,
        qrTransferDecodeFps,
        qrTransferReceiveSpeed,
        qrTransferElapsed,
        qrTransferNewFrames,
        qrTransferDuplicateFrames,
        qrTransferBlockSize,
        qrTransferBlockCount,
        qrTransferFileData,
        qrTransferFileDataDetail,
        qrTransferSessionMismatch,
        qrTransferChecksumFailed,
        qrTransferRawLengthMismatch,
        qrTransferDecompressionFailed,
        qrTransferResourceLimit,
        qrTransferSessionExpired,
        qrTransferDecodeFailed,
        qrTransferFullBackupWarning,
        qrTransferImportFullBackup,
        transferOverviewTitle,
        courseCountBullet,
        currentTimetableBullet,
        allTimetablesBullet,
        timeSchemeCountBullet,
        currentWeekBullet,
        semesterStartUnsetBullet,
        semesterStartBullet,
        fileExtensionBullet,
        dataTransferUndoSuccess,
        dataTransferUndoFailed,
        selectImportModeTitle,
        selectImportModeMessage,
        selectImportModeMerge,
        replaceCurrentTimetable,
        importAsNewTimetable,
        createdNewTimetableAfterImport,
        transferImportedProfileName,
        transferImportedTimeSchemeName,
        backupRestoredSuccess,
        importFailedInvalidFile,
        importFileReadFailed,
        importFileTooLarge,
        importPartialSkippedSuffix,
        coursesBeyondSchemeExtraSuffix,
        sendFailedWithError,
        themeUndo,
        cancelAction,
    )
}
