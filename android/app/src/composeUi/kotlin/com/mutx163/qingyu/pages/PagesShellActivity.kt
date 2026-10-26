package com.mutx163.qingyu.pages

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.pages.about.AboutStaticPage
import com.mutx163.qingyu.pages.about.OpenSourceLicensesPage
import com.mutx163.qingyu.pages.about.OpenSourcePackageLicense
import com.mutx163.qingyu.pages.about.SupportCreatorPage
import com.mutx163.qingyu.pages.about.SupportDonorData
import com.mutx163.qingyu.pages.about.SupportDonorEntry
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * Compose 迁移 Phase 3 · 页面开发壳（composeUi 变体专属）。
 *
 * 作用：把已移植的页面挂上真实入口，好让「新老版本同屏对照」这件事能真的做起来。
 * 带 `.ui` 包名后缀，与正式版/调试版并存，**不会覆盖用户手机上的正式版**。
 *
 * ## 数据是示例值，不是真实数据
 *
 * 本壳是独立包名，读不到正式版的 FlutterSharedPreferences（那是 Phase 1 覆盖安装
 * 才验证的能力）。静态页不需要数据；列表类页面这里喂**示例条目**，只为看清版式与
 * 文案，界面上也有明确标注。真实数据接线属于后续批次。
 */
class PagesShellActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MiuixTheme {
                PagesShell()
            }
        }
    }
}

/** 壳内路由。不引导航库，三个页面各自独立，一个状态变量足够。 */
private enum class ShellRoute { MENU, ABOUT, LICENSES, SUPPORT }

@Composable
private fun PagesShell() {
    var route by remember { mutableStateOf(ShellRoute.MENU) }

    when (route) {
        ShellRoute.MENU -> ShellMenu(onOpen = { route = it })
        ShellRoute.ABOUT -> AboutStaticPage(
            onBack = { route = ShellRoute.MENU },
            onEntryClick = { entry ->
                // 静态区里点「开源许可」直接进许可页；其余入口留待后续批次接线。
                if (entry.kind == com.mutx163.qingyu.pages.about.AboutEntryKind.OPEN_SOURCE_LICENSES) {
                    route = ShellRoute.LICENSES
                }
            },
        )

        ShellRoute.LICENSES -> OpenSourceLicensesPage(
            packages = sampleLicenses(),
            onBack = { route = ShellRoute.MENU },
            onOpenPackage = { /* 详情页由壳内再叠一层，本批先不接 */ },
        )

        ShellRoute.SUPPORT -> SupportCreatorPage(
            donorData = sampleDonors(),
            onBack = { route = ShellRoute.MENU },
            onReload = { },
            onSaveQr = { },
        )
    }
}

@Composable
private fun ShellMenu(onOpen: (ShellRoute) -> Unit) {
    val colors = MiuixTheme.colorScheme
    Scaffold(containerColor = colors.surface) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .verticalScroll(rememberScrollState())
                .padding(innerPadding)
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text(
                text = "轻屿课表 · Compose 页面壳",
                fontSize = 24.sp,
                fontWeight = FontWeight.Bold,
                color = colors.onSurface,
                modifier = Modifier.padding(top = 16.dp),
            )
            Text(
                text = "Phase 3 页面移植对照用。独立包名（.ui），不影响正式版与调试版。",
                fontSize = 12.sp,
                lineHeight = 18.sp,
                color = colors.onSurfaceVariantSummary,
            )
            Text(
                text = "列表类页面显示的是示例数据，用于核对版式与文案；真实数据接线在后续批次。",
                fontSize = 12.sp,
                lineHeight = 18.sp,
                color = colors.onSurfaceVariantSummary,
                modifier = Modifier.padding(bottom = 6.dp),
            )

            MenuRow("关于页（静态信息区）", "支持与更新 / 产品 / 社区 三段列表") { onOpen(ShellRoute.ABOUT) }
            MenuRow("开源许可页", "搜索框 + 许可说明 + 组件列表") { onOpen(ShellRoute.LICENSES) }
            MenuRow("支持作者页", "头图 + 收款方式 + 鸣谢名单") { onOpen(ShellRoute.SUPPORT) }
        }
    }
}

@Composable
private fun MenuRow(title: String, subtitle: String, onClick: () -> Unit) {
    val colors = MiuixTheme.colorScheme
    Card(
        modifier = Modifier.fillMaxWidth().clickable { onClick() },
        insideMargin = PaddingValues(14.dp),
    ) {
        Column {
            Text(
                text = title,
                fontSize = 16.sp,
                fontWeight = FontWeight.Medium,
                color = colors.onSurface,
            )
            Text(
                text = subtitle,
                fontSize = 12.sp,
                lineHeight = 18.sp,
                color = colors.onSurfaceVariantSummary,
                modifier = Modifier.padding(top = 4.dp),
            )
        }
    }
}

/** 示例许可条目（仅用于看版式；真实数据来自 Flutter 侧 LicenseRegistry）。 */
private fun sampleLicenses(): List<OpenSourcePackageLicense> = listOf(
    OpenSourcePackageLicense(
        packageName = "flutter",
        licenseBodies = listOf("Copyright 2014 The Flutter Authors.\n\nBSD 3-Clause License"),
    ),
    OpenSourcePackageLicense(
        packageName = "miuix",
        licenseBodies = listOf("Apache License 2.0"),
    ),
    OpenSourcePackageLicense(
        packageName = "shared_preferences",
        licenseBodies = listOf("BSD 3-Clause License"),
    ),
)

/** 示例鸣谢名单（仅用于看版式；真实数据来自在线名单）。 */
private fun sampleDonors(): SupportDonorData = SupportDonorData(
    title = "鸣谢名单",
    updatedAt = "2026-10-20",
    donors = listOf(
        SupportDonorEntry(name = "示例支持者甲", amount = "￥20", date = "2026-10-20", message = "加油"),
        SupportDonorEntry(name = "示例支持者乙", amount = "￥10", date = "2026-10-05"),
        SupportDonorEntry(name = "示例支持者丙", date = "2026-09-30", message = "课表很好用"),
    ),
)
