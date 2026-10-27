package com.mutx163.qingyu.pages.statistics

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TopAppBar
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Alarm
import top.yukonga.miuix.kmp.icon.extended.Back
import top.yukonga.miuix.kmp.preference.SwitchPreference

/**
 * 统计设置页 · Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/statistics_settings_screen.dart`：
 * - 顶栏：返回 + "统计设置"
 * - 一块设置分组（块头 "本周课程小结"），组内一行开关：
 *   标题 "本周课程小结"，副标题按开关态取「下次推送 {日期} {时间}」或「已关闭每周周报推送」
 *
 * 不持业务状态、不做业务计算：下次推送时刻与副标题都在
 * [StatisticsSettingsLogic.buildViewState] 里算好，这里只画。
 *
 * 注：块头与开关行标题在 Dart 原文里是同一个 ARB 键（`weeklyReportTitle`），
 * 屏上念两遍是既有行为，本次迁移不改文案。
 */
@Composable
fun StatisticsSettingsPage(
    viewState: StatisticsSettingsViewState,
    onBack: () -> Unit,
    onWeeklyReportToggle: (Boolean) -> Unit,
) {
    val dark = isSystemInDarkTheme()

    Scaffold(containerColor = Color(QingyuTheme.scaffoldBackground(dark))) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                // 不手写 statusBarsPadding()：miuix Scaffold 的 contentWindowInsets
                // 默认含 systemBars 顶部，TopAppBar 自己也会加 systemBars.only(Top)，
                // 再写一次是第三次叠加，标题会下移一个多状态栏高（2026-10-27）。
                .padding(innerPadding),
        ) {
            TopAppBar(
                title = viewState.title,
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            imageVector = MiuixIcons.Back,
                            contentDescription = viewState.title,
                            tint = Color(QingyuTheme.actionIcon(dark)),
                        )
                    }
                },
            )

            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                // 分组块头（HyperosSettingsBlock.title）
                Text(
                    text = viewState.sectionTitle,
                    fontSize = 13.sp,
                    color = Color(QingyuTheme.sectionLabel(dark)),
                    modifier = Modifier.padding(start = 4.dp, top = 8.dp, bottom = 4.dp),
                )

                Card(
                    modifier = Modifier.fillMaxWidth(),
                    insideMargin = PaddingValues(vertical = 2.dp),
                ) {
                    SwitchPreference(
                        checked = viewState.isEnabled,
                        onCheckedChange = onWeeklyReportToggle,
                        title = viewState.tileTitle,
                        summary = viewState.subtitle,
                        startAction = {
                            Icon(
                                imageVector = MiuixIcons.Alarm,
                                contentDescription = null,
                                tint = Color(QingyuTheme.primary(dark = dark)),
                                modifier = Modifier
                                    .padding(horizontal = 4.dp)
                                    .size(20.dp),
                            )
                        },
                    )
                }
            }
        }
    }
}
