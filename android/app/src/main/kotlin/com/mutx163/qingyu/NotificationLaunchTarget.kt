package com.mutx163.qingyu

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import com.mutx163.qingyu.pages.PagesShellActivity

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
 * ## 落点（如实说明）
 *
 * 壳当前不读 Intent 里的页面参数，所以点通知后落在壳的默认主屏：冷启动按
 * `timetableHomeViewMode` 进周视图（`c1.week`）或月视图（`c2.month`），都是课表页，
 * 不会开出空白首页；壳若已在运行（`singleTop`），只把任务带回前台，停留当前页。
 */
object NotificationLaunchTarget {

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
}
