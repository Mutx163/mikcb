package com.mutx163.qingyu.core.permission

import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.io.File

/**
 * 权限两条守卫（权限对齐第二步，2026-11-03）。
 *
 * 1. **清单声明守卫**：代码里通过 `Manifest.permission.X` 查询 / 申请的每一个运行时权限，
 *    都必须在 `AndroidManifest.xml` 声明过——漏声明的权限系统框根本弹不出来，
 *    `checkSelfPermission` 恒为 denied，表现为「永远申请不上」的静默失败。
 *    只拦「用了没声明」；「声明了没用」不拦（历史声明可能供系统组件使用，删不删由人决定）。
 * 2. **共用状态机守卫**：天气域与日程域（`pages/weather`、`pages/schedule`）里凡是挂了
 *    权限 launcher 的宿主，必须走 `core/permission` 的 [PermissionFlow]——不许各页再拼
 *    一套「查权限 + 弹框 + 判断拒绝」；也不许直接调系统 `shouldShowRequestPermissionRationale`
 *    或自拼 `Settings.ACTION_*` 跳设置 Intent（统一走 `platform/permission` 适配层）。
 *    相机域（`pages/transfer/QrCameraHost`）豁免：它已按 `share/camera` 自己的状态机
 *    对齐旧版，语义与本层一致，合并是后续重构不是本守卫的事。
 *
 * 判定一律先剥注释（行注释 + 块注释 + 字符串字面量）再匹配关键字，
 * 防止注释里的示例代码把守卫喂出假红或被人当免死金牌。
 */
class PermissionManifestGuardTest {

    // ---- 定位仓库根（与 FlutterAssetsDecouplingGuardTest 同一套向上找法） ----

    private fun repoRoot(): File {
        var dir: File? = File(System.getProperty("user.dir") ?: ".").absoluteFile
        while (dir != null) {
            if (File(dir, "pubspec.yaml").isFile && File(dir, "android").isDirectory) return dir
            dir = dir.parentFile
        }
        error("找不到仓库根（user.dir=${System.getProperty("user.dir")}）")
    }

    private fun manifestFile(): File =
        File(repoRoot(), "android/app/src/main/AndroidManifest.xml")

    private fun kotlinSourcesUnder(relative: String): List<File> {
        val dir = File(repoRoot(), relative)
        return if (dir.isDirectory) dir.walkTopDown().filter { it.isFile && it.extension == "kt" }.toList()
        else emptyList()
    }

    // ---- 判定核心（internal 供探针用例直接喂假内容） ----

    /** 剥掉块注释、行注释与字符串字面量（顺序：块注释 → 字符串 → 行注释，防止 "https://" 干扰）。 */
    internal fun stripCommentsAndStrings(source: String): String = source
        .replace(Regex("(?s)/\\*.*?\\*/"), " ")
        .replace(Regex("\"\"\".*?\"\"\""), " ")
        .replace(Regex("\"(?:\\\\.|[^\"\\\\\\n])*\""), " ")
        .replace(Regex("//[^\\n]*"), " ")

    /** 从（已剥注释的）源码里提取 `Manifest.permission.X` 引用的权限名。 */
    internal fun referencedPermissions(strippedSource: String): Set<String> =
        Regex("Manifest\\.permission\\.([A-Z_]+)").findAll(strippedSource)
            .map { it.groupValues[1] }.toSet()

    /** 从清单文本里提取 `<uses-permission android:name="…">` 的权限全名。 */
    internal fun declaredPermissions(manifestXml: String): Set<String> =
        Regex("<uses-permission\\s+android:name=\"([^\"]+)\"").findAll(manifestXml)
            .map { it.groupValues[1] }.toSet()

    // ---- 守卫 1：代码用到的权限必须在清单里声明 ----

    @Test
    fun `代码引用的每个 Manifest 权限都必须在清单里声明`() {
        val declared = declaredPermissions(manifestFile().readText())
        val sources = kotlinSourcesUnder("android/app/src/main/kotlin") +
            kotlinSourcesUnder("android/app/src/composeP1/kotlin")
        val undeclared = mutableMapOf<String, MutableList<String>>()
        for (source in sources) {
            for (name in referencedPermissions(stripCommentsAndStrings(source.readText()))) {
                val fullName = "android.permission.$name"
                if (fullName !in declared) {
                    undeclared.getOrPut(name) { mutableListOf() }
                        .add(source.relativeTo(repoRoot()).path)
                }
            }
        }
        assertTrue(
            "以下权限在代码中被引用但清单未声明（系统框弹不出来，等于永远申请不上）: $undeclared",
            undeclared.isEmpty(),
        )
    }

    // ---- 守卫 2：天气 / 日程域必须走共用状态机与适配层 ----

    /** 守卫范围：天气两宿主（CityPicker 在 pages/weather，SettingsHost 在 app/）+ 日程域。 */
    private val flowDrivenTargets = listOf(
        "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/weather",
        "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/schedule",
        "android/app/src/composeP1/kotlin/com/mutx163/qingyu/app/WeatherSettingsHost.kt",
    )

    private fun sourcesUnderAny(path: String): List<File> {
        val f = File(repoRoot(), path)
        return when {
            f.isDirectory -> f.walkTopDown().filter { it.isFile && it.extension == "kt" }.toList()
            f.isFile -> listOf(f)
            else -> emptyList()
        }
    }

    private val launcherPattern = Regex(
        "rememberLauncherForActivityResult[\\s\\S]{0,120}ActivityResultContracts\\.(RequestMultiplePermissions|RequestPermission)\\b",
    )
    private val forbiddenPatterns = linkedMapOf(
        "裸调 shouldShowRequestPermissionRationale（应走 PermissionSystemActions.canAskAgain）" to
            Regex("\\.shouldShowRequestPermissionRationale\\s*\\("),
        "自拼应用详情设置 Intent（应走 PermissionSystemActions.openAppDetailsSettings）" to
            Regex("ACTION_APPLICATION_DETAILS_SETTINGS"),
        "自拼通知设置 Intent（应走 PermissionSystemActions.openNotificationSettings）" to
            Regex("ACTION_APP_NOTIFICATION_SETTINGS"),
    )

    @Test
    fun `天气与日程域挂权限 launcher 的文件必须走 PermissionFlow 且不得自拼系统调用`() {
        val violations = mutableListOf<String>()
        for (domain in flowDrivenTargets) {
            for (source in sourcesUnderAny(domain)) {
                val stripped = stripCommentsAndStrings(source.readText())
                val usesLauncher = launcherPattern.containsMatchIn(stripped)
                val importsFlow = "import com.mutx163.qingyu.core.permission.PermissionFlow" in stripped
                if (usesLauncher && !importsFlow) {
                    violations += "${source.name}: 挂了权限 launcher 但未 import PermissionFlow"
                }
                for ((reason, pattern) in forbiddenPatterns) {
                    if (pattern.containsMatchIn(stripped)) {
                        violations += "${source.name}: $reason"
                    }
                }
            }
        }
        assertTrue(
            "天气/日程域各写一套权限流程（不许，见 core/permission/PermissionFlow）:\n" +
                violations.joinToString("\n"),
            violations.isEmpty(),
        )
    }

    // ---- 咬合探针（函数级：喂假内容证明守卫真的会红） ----

    @Test
    fun `探针-未声明权限的假源码必须被判红`() {
        // 把 PermissionFlow.kt 的真实内容喂给守卫 1 的判定链，并在其中伪造一个未声明权限引用。
        val real = File(repoRoot(), "android/app/src/main/kotlin/com/mutx163/qingyu/core/permission/PermissionFlow.kt")
        val faked = real.readText().replace(
            "class PermissionFlow(initiallyGranted: Boolean = false)",
            "val probe = Manifest.permission.READ_CONTACTS\nclass PermissionFlow(initiallyGranted: Boolean = false)",
        )
        val declared = declaredPermissions(manifestFile().readText())
        val names = referencedPermissions(stripCommentsAndStrings(faked))
        assertTrue("探针前提：伪造内容里确实引用了 READ_CONTACTS", "READ_CONTACTS" in names)
        assertTrue(
            "探针必须红：READ_CONTACTS 不在清单里，判定必须检出",
            "android.permission.READ_CONTACTS" !in declared,
        )
    }

    @Test
    fun `探针-裸拼跳设置 Intent 的假源码必须被守卫2判红`() {
        val faked = """
            import android.provider.Settings
            import androidx.activity.compose.rememberLauncherForActivityResult
            import androidx.activity.result.contract.ActivityResultContracts
            val c = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {}
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
        """.trimIndent()
        assertTrue("探针前提：假内容命中 launcher 判定", launcherPattern.containsMatchIn(stripCommentsAndStrings(faked)))
        for ((_, pattern) in forbiddenPatterns) {
            if (pattern.containsMatchIn(stripCommentsAndStrings(faked))) return
        }
        fail("探针必须红：ACTION_APPLICATION_DETAILS_SETTINGS 应被守卫 2 检出")
    }

    @Test
    fun `探针-真实天气宿主当前确实接线了 PermissionFlow（守卫2对现状为绿的前提）`() {
        val host = File(
            repoRoot(),
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/weather/WeatherCityPickerHost.kt",
        )
        val stripped = stripCommentsAndStrings(host.readText())
        assertTrue("天气宿主应挂权限 launcher", launcherPattern.containsMatchIn(stripped))
        assertTrue(
            "天气宿主应 import PermissionFlow（拆掉接线后本探针红，提醒同步改守卫）",
            "import com.mutx163.qingyu.core.permission.PermissionFlow" in stripped,
        )
    }
}
