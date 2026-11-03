package com.mutx163.qingyu

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import com.mutx163.qingyu.pages.PagesShellActivity
import com.mutx163.qingyu.pages.ShellExternalEntryHub

/**
 * 通知被点开时该跳哪个 Activity。
 *
 * ## 为什么不能继续写死 Flutter 入口
 *
 * 正式包（prod）与 `dev` / `perf` 的启动页都是 [PagesShellActivity]；只有 `itest`
 * 变体在 `src/itest/AndroidManifest.xml` 里把启动页换回 Flutter 的 `MainActivity`。
 * 四处通知（考试提醒、周报、实时活动、局域网前台服务）此前都硬编码指向
 * Flutter 入口，在 dev / perf 包里等于指向一个被禁用的组件——通知栏能看见，
 * 点下去打不开应用。
 *
 * ## 判据
 *
 * 不按变体名写死，而是问系统「本包当前的启动 Activity 是谁」
 *（`ACTION_MAIN` + `CATEGORY_LAUNCHER` + 精确包名）。各变体共用同一套代码，
 * 以后新增变体也不用再改这里。解析不到时退回壳入口 [PagesShellActivity]
 *（正式包与 dev / perf 都必然存在；itest 能正常解析到 Flutter 入口，不走这里）。
 *
 * 返回值只决定目标组件，调用方原有的 extras / flags 照旧叠加。
 *
 * ## 落点（页面参数契约，2026-11-03 R09）
 *
 * 本对象同时是**通知点击落页**的唯一契约点。生产端只写下面两个 extra，消费端只认它们：
 *
 * | extra | 类型 | 取值 | 落点 |
 * |---|---|---|---|
 * | [EXTRA_OPEN_ROUTE] | String | Dart 路由串（如 [ROUTE_EXAMS]） | [pageIdForRoute] 映射到的壳页面 id |
 * | [EXTRA_OPEN_LAN_EDIT] | Boolean | `true` | 局域网编辑页 `g3.lanEdit` |
 *
 * 规则：
 * - 显式 `open_route` 优先；只有它缺失 / 空白时才看 `open_lan_edit`。
 * - 映射不到的路由**不猜**，返回 null（落壳默认主屏），与外部深链「未知路由 no-op」同口径。
 * - 路由 → 页面 id 的对应表在 [pageIdForRoute]：这是一个**封闭契约**，生产端新增落点
 *   必须在这里补一行 + 补契约测试（`NotificationLaunchPageContractTest`），不要散到调用方。
 *
 * ## 两条启动路径
 *
 * 壳 [PagesShellActivity] 必须在 **`onCreate`（冷启动）** 和 **`onNewIntent`
 * （后台 singleTop 复用）** 各调用一次 [postLaunchPage]。解析结果投进
 * [ShellExternalEntryHub]，壳里既有的 `ShellExternalEntryEffect` 负责推页——
 * 冷启动时组合树尚未建立也能落页（hub 是进程级状态），后台复用则靠状态变化触发重组。
 * 已解析的 extra 会被移除，Activity 重建（旋转等）不会重复推同一页。
 * 壳文件是 Lead 专属写作用域，补丁见 `.agents/notes/R09-pages-shell-patch.diff`。
 *
 * 兜底：目标始终是系统当前的启动 Activity（见 [intent]），所以 itest 变体的 Flutter
 * 宿主仍按原行为打开；那一路不消费本契约，落点由 Flutter 自己决定。
 */
object NotificationLaunchTarget {

    // ── 页面参数契约（生产端与壳共同冻结的字面量）─────────────────────────────

    /** 显式路由 extra：值是 [ROUTE_EXAMS] 这类 Dart 路由串。 */
    const val EXTRA_OPEN_ROUTE = "open_route"

    /**
     * 局域网编辑页的旧布尔 extra（`LanEditForegroundService.buildOpenLanEditIntent`
     * 与 Flutter `MainActivity` 都按这个键读），保留原值以免破坏 itest 兼容。
     */
    const val EXTRA_OPEN_LAN_EDIT = "open_lan_edit"

    /** 考试提醒的路由值：点击后落到考试列表页。 */
    const val ROUTE_EXAMS = "/exams"

    /** [ROUTE_EXAMS] 的落点：壳页面 id `d3.examList`（`ShellPageCatalog` 的考试列表）。 */
    const val PAGE_EXAMS = "d3.examList"

    /** 局域网编辑的落点：壳页面 id `g3.lanEdit`。 */
    const val PAGE_LAN_EDIT = "g3.lanEdit"

    fun intent(context: Context): Intent {
        val launcher = Intent(Intent.ACTION_MAIN)
            .addCategory(Intent.CATEGORY_LAUNCHER)
            .setPackage(context.packageName)
        val resolved = context.packageManager
            .resolveActivity(launcher, PackageManager.MATCH_DEFAULT_ONLY)
        val component = resolved?.activityInfo?.let { ComponentName(it.packageName, it.name) }
        return if (component != null) {
            Intent().setComponent(component)
        } else {
            Intent(context, PagesShellActivity::class.java)
        }
    }

    /**
     * 纯逻辑：extra 值 → 壳页面 id，映射不到返回 null。
     *
     * 不碰 `Intent`，供 JVM 单测直接断言落点（契约测试见
     * `NotificationLaunchPageContractTest`）。
     */
    fun pageIdFor(openRoute: String?, openLanEdit: Boolean): String? {
        val route = openRoute?.trim().orEmpty()
        if (route.isNotEmpty()) return pageIdForRoute(route)
        return if (openLanEdit) PAGE_LAN_EDIT else null
    }

    /**
     * 通知路由串 → 壳页面 id 的**封闭映射表**。
     *
     * 刻意不转调 `ShellWiring.shellPageIdForRoute`：那张表是设置页出站路由的全集，
     * 而通知是跨进程/跨版本的对外契约，必须逐条显式登记、逐条有测；依赖大表会让
     * 别人补一行设置路由就悄悄改变通知行为。新增通知落点 = 这里加一行 + 补契约测试。
     */
    fun pageIdForRoute(route: String): String? = when (route) {
        ROUTE_EXAMS -> PAGE_EXAMS
        "/settings/lan-edit" -> PAGE_LAN_EDIT
        else -> null
    }

    /** 从点击 Intent 读契约 extra 并解析落点；没有页面参数返回 null。 */
    fun pageIdForIntent(intent: Intent?): String? = pageIdFor(
        openRoute = intent?.getStringExtra(EXTRA_OPEN_ROUTE),
        openLanEdit = intent?.getBooleanExtra(EXTRA_OPEN_LAN_EDIT, false) == true,
    )

    /**
     * 壳在 `onCreate` / `onNewIntent` 调用的唯一入口：解析后投进
     * [ShellExternalEntryHub]，由壳里既有的消费钩子推页。
     *
     * 投递成功后清掉这两个 extra：Activity 因旋转 / 进程恢复重建时会带着同一份
     * Intent 再走一次 `onCreate`，不清就会把用户已经关掉的页面重新推出来。
     * 没有页面参数时什么都不做（普通点图标启动不产生推页）。
     */
    fun postLaunchPage(intent: Intent?) {
        val pageId = pageIdForIntent(intent) ?: return
        intent?.removeExtra(EXTRA_OPEN_ROUTE)
        intent?.removeExtra(EXTRA_OPEN_LAN_EDIT)
        ShellExternalEntryHub.post(pageId, payload = null)
    }
}
