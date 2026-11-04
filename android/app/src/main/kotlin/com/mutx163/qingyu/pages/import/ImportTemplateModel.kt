package com.mutx163.qingyu.pages.import

/**
 * 「下载轻屿课表模板」的**内容与落点契约**（纯 Kotlin，无 Android 依赖）。
 *
 * ## 内容从哪来
 *
 * Dart 侧这份模板是**打包资产**（`assets/templates/mikcb_course_import_template.csv`），
 * 走 `rootBundle.load` 读出来再 `SharePlus` 分享（`spreadsheet_course_import_screen.dart:120-141`）。
 * Kotlin 侧不走资产：`assets/flutter_assets/...` 只有在**带 Flutter 资源链**的构建里才存在，
 * 而本仓 L1 编译闸门默认 `-x :app:compileFlutterBuild*`（见 AGENTS.md「编译分工」），
 * 依赖那条链的文件在纯 Kotlin 构建里读不到。
 *
 * 所以这里**逐字内联同一份内容**，并由 `ImportTemplateModelTest` 做两件事：
 * 1. 与仓库里的资产文件**逐字节对拍**（两边漂了立刻红）；
 * 2. 把这份模板真的丢进 [SpreadsheetImportModel] 解析一遍，断言能出 3 门课
 *    （模板本身不可导入 = 用户下载到一份废纸）。
 *
 * ## 落点
 *
 * `cacheDir/transfer-share/`：`res/xml/file_paths.xml` 里**已登记**的 `<cache-path>`
 * （`transfer-share/`），FileProvider 能把它授给分享面板；不新开目录 = 不用碰
 * `res/xml` 与 manifest（那是 Lead 的共享件）。
 */
object ImportTemplateModel {

    /** 用户看到的文件名（与 Dart 侧临时文件同名，用户对比文档时不打架）。 */
    const val FILE_NAME: String = "mikcb_course_import_template.csv"

    /** 分享出去时的 MIME：CSV 用 `text/csv`，别用 `application/json`（那会让接收方按 JSON 打开）。 */
    const val MIME_TYPE: String = "text/csv"

    /** 已登记的缓存子目录（`res/xml/file_paths.xml`: `<cache-path name="transfer_share" path="transfer-share/" />`）。 */
    const val SHARE_DIR_NAME: String = "transfer-share"

    /** 相对 `cacheDir` 的落盘路径。 */
    val CACHE_RELATIVE_PATH: String = "$SHARE_DIR_NAME/$FILE_NAME"

    /**
     * 模板正文（**与 `assets/templates/mikcb_course_import_template.csv` 逐字节一致**）。
     *
     * 首行 `# mikcb-course-import-v1` 是格式标记，[SpreadsheetImportModel] 靠它认
     * `FORMAT_MIKCB`；下面三行是示例课（高数 / 大学英语 / 程序设计），覆盖
     * 「只用周次」「用上课周表达式」「带时间与颜色」三种填法。
     */
    val CONTENT: String = buildString {
        append("# mikcb-course-import-v1\r\n")
        append("课程名,星期,开始节,结束节,上课周,简称,教师,教室,开始时间,结束时间,颜色,停课周,性质,简介,备注,时间模板\r\n")
        append("高等数学,1,1,2,1-16,高数,张老师,A101,,,#2196F3,,必修,微积分基础,,\r\n")
        append("大学英语,3,3,4,1-8、10-16,,无,教学楼201,,,,,选修,,口语强化,\r\n")
        append("程序设计,5,5,6,1-5、7-11单,程设,李老师,实验室,14:00,15:40,4CAF50,6,必修,Python入门,实验课需自带电脑,default\r\n")
    }
}
