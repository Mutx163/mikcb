package com.mutx163.qingyu

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager

/**
 * 通知被点开时该跳哪个 Activity。
 *
 * ## 为什么不能继续写死 [MainActivity]
 *
 * 正式包（prod）的入口是 Flutter 的 [MainActivity]；但 `dev` / `bench` 变体在
 * `src/dev/AndroidManifest.xml` 里把 `MainActivity` 置为 `enabled="false"`，改由
 * [com.mutx163.qingyu.pages.PagesShellActivity] 作为启动页。四处通知（考试提醒、
 * 周报、实时活动、局域网前台服务）此前都硬编码 `Intent(context, MainActivity::class.java)`，
 * 在 dev 包里点通知等于指向一个被禁用的组件——通知栏能看见，点下去打不开应用。
 *
 * ## 判据
 *
 * 不按变体名写死，而是问系统「本包当前的启动 Activity 是谁」
 *（`ACTION_MAIN` + `CATEGORY_LAUNCHER` + 精确包名）。两种变体共用同一套代码，
 * 以后新增变体也不用再改这里。解析不到时退回 [MainActivity]，保持旧行为。
 *
 * 返回值只决定目标组件，调用方原有的 extras / flags 照旧叠加。
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
            Intent(context, MainActivity::class.java)
        }
    }
}
