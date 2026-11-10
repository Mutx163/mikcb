package com.mutx163.qingyu.pages.sync

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuLoadingInButton
import com.mutx163.qingyu.components.QingyuSheet
import com.mutx163.qingyu.components.rememberCappedSheetHeight
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.theme.MiuixTheme
import top.yukonga.miuix.kmp.utils.overScrollVertical
import top.yukonga.miuix.kmp.utils.scrollEndHaptic

/**
 * 「连接坚果云情侣课表」弹层（Dart `lib/widgets/couple_webdav_connect_sheet.dart`）。
 *
 * ## 为什么由宿主托管、而不是页面自己弹
 *
 * 页面签名固定为 `onAction(actionId: String)`——它带不了「账号 / 密码 / 槽位」三个值。
 * 所以页面只把「连接坚果云」转成 [CoupleTimetableSettingsLogic.WEBDAV_CONNECT]，
 * 弹层与两个动作由宿主（`CoupleTimetableSettingsHost`）接住。
 *
 * ## 逐条对位 Dart
 *
 * | Dart | 这里 |
 * |---|---|
 * | 标题 + 副标题（`coupleWebdavLoginSheetTitle/Subtitle`） | [CoupleWebdavSheetTexts.title] / `.subtitle` |
 * | 账号框（初值 = 配置里的 username） | 同名 TextField，初值 [initialUsername] |
 * | 应用专用密码框（`obscureText: true`） | `PasswordVisualTransformation()` |
 * | 本机槽位 1 / 2 二选一，选中态为主色 | 两个 `Button`，选中用 `buttonColorsPrimary()`、未选中用 `buttonColors()` |
 * | 槽位说明（`coupleWebdavMySlotHint`） | [CoupleWebdavSheetTexts.slotHint] |
 * | 底部「测试连接」(次要) + 「连接并拉取」(主色)，`PickerSheetScaffold` actions 槽固定在弹层底部 | 同排两个 `Button`，各 `weight(1f)`、固定在滚动字段区之下；前者 `buttonColors()`、后者 `buttonColorsPrimary()` |
 * | 账号或密码为空 / 正在忙 → 两个按钮都不可点 | `credentialsFilled && !busy` |
 *
 * 弹层内部只剩「输入框里现在是什么」这一类 UI 态；网络与落盘都在宿主侧。
 *
 * ## 常驻组合（2026-11-03 弹窗审核 P3 收口）
 *
 * 本组件**常驻组合**，可见性只由 [show] 驱动——旧版 `show = true` 静态写在组件里、
 * 靠宿主 `if (showConnectSheet)` 整棵移出组合来关闭，官方退场动画一次都播不出来。
 * 文本/忙碌态全部来自宿主 [texts]（随 viewState 稳定存在），退场期间无需快照保底；
 * 每次打开（[show] 翻 true）把三格输入重置回宿主初值，与旧版「重新挂载 = 清空」同语义。
 */
@Composable
fun CoupleWebdavConnectSheet(
    show: Boolean,
    texts: CoupleWebdavSheetTexts,
    initialUsername: String,
    initialSlot: Int,
    testing: Boolean,
    connecting: Boolean,
    onDismissRequest: () -> Unit,
    onTest: (username: String, password: String) -> Unit,
    onConfirm: (username: String, password: String, mySlot: Int) -> Unit,
) {
    val dark = isSystemInDarkTheme()
    var username by remember { mutableStateOf(initialUsername) }
    var password by remember { mutableStateOf("") }
    var slot by remember { mutableStateOf(if (initialSlot == 2) 2 else 1) }
    // 常驻后重组不再重建组件：每次打开重新吃宿主初值（旧版靠重新挂载天然做到）。
    LaunchedEffect(show, initialUsername, initialSlot) {
        if (show) {
            username = initialUsername
            password = ""
            slot = if (initialSlot == 2) 2 else 1
        }
    }

    // Dart `_credentialsFilled`：两项都填了才允许测试/连接（否则点了只会闪一下转圈，不说原因）。
    val credentialsFilled = username.trim().isNotEmpty() && password.isNotEmpty()
    val busy = testing || connecting

    // 弹层常驻组合、show 由宿主驱动（2026-11-03 弹层审计）：宿主原先
    // `if (showConnectSheet) { …(show = true) }` 条件挂载，关闭时 260ms 退场动画一次不播。
    QingyuSheet(
        show = show,
        title = texts.title,
        onDismissRequest = onDismissRequest,
        // 同 [CloudBackupDetailSheet]：内容自留 4dp，框架侧仍给 16dp（合计 20dp，对齐页面口径）。
        contentPadsHorizontally = false,
        // 字段区自己滚（矮屏/键盘弹起时先收缩、内部滚动），
        // 「测试连接 / 连接并拉取」固定在弹层底部——Dart `PickerSheetScaffold` 的 actions 槽同位
        //（原先动作行混在可滚内容里，键盘弹出时主按钮可能被推出可视区，弹层审计 #337）。
        contentScrolls = true,
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            // 字段区惰性列表（样式守卫 R2：主滚动必须 LazyColumn，不用 Column+verticalScroll）：
            // 矮屏/键盘弹起时先收缩（weight fill=false）、内部滚动，动作行固定在弹层底部。
            LazyColumn(
                modifier = Modifier
                    .weight(1f, fill = false)
                    .fillMaxWidth()
                    .heightIn(max = rememberCappedSheetHeight(360.dp))
                    .scrollEndHaptic()
                    .overScrollVertical()
                    .padding(horizontal = 4.dp),
            ) {
                item(key = "fields") {
                    Column(modifier = Modifier.fillMaxWidth()) {
                        Text(
                            text = texts.subtitle,
                            style = MiuixTheme.textStyles.footnote1,
                            color = Color(QingyuTheme.secondaryText(dark)),
                        )
                        Spacer(modifier = Modifier.height(16.dp))
                        TextField(
                            value = username,
                            onValueChange = { username = it },
                            label = texts.usernameLabel,
                            useLabelAsPlaceholder = true,
                            modifier = Modifier.fillMaxWidth(),
                        )
                        Spacer(modifier = Modifier.height(12.dp))
                        TextField(
                            value = password,
                            onValueChange = { password = it },
                            label = texts.passwordLabel,
                            useLabelAsPlaceholder = true,
                            visualTransformation = PasswordVisualTransformation(),
                            modifier = Modifier.fillMaxWidth(),
                        )
                        Spacer(modifier = Modifier.height(16.dp))
                        Text(
                            text = texts.slotLabel,
                            style = MiuixTheme.textStyles.body2,
                            color = Color(QingyuTheme.secondaryText(dark)),
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(12.dp),
                        ) {
                            SlotButton(
                                label = texts.slotOne,
                                selected = slot == 1,
                                enabled = !busy,
                                onClick = { slot = 1 },
                                modifier = Modifier.weight(1f),
                            )
                            SlotButton(
                                label = texts.slotTwo,
                                selected = slot == 2,
                                enabled = !busy,
                                onClick = { slot = 2 },
                                modifier = Modifier.weight(1f),
                            )
                        }
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text = texts.slotHint,
                            style = MiuixTheme.textStyles.footnote1,
                            color = Color(QingyuTheme.secondaryText(dark)),
                        )
                    }
                }
            }
            Spacer(modifier = Modifier.height(16.dp))
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 4.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                // 次要：先测连接（不落盘）。
                Button(
                    onClick = { onTest(username.trim(), password) },
                    enabled = credentialsFilled && !busy,
                    colors = ButtonDefaults.buttonColors(),
                    modifier = Modifier.weight(1f),
                ) {
                    if (testing) {
                        QingyuLoadingInButton()
                        Spacer(modifier = Modifier.width(8.dp))
                    }
                    Text(text = texts.testLabel)
                }
                // 主色：连上并立刻拉一次对方课表。
                Button(
                    onClick = { onConfirm(username.trim(), password, slot) },
                    enabled = credentialsFilled && !busy,
                    colors = ButtonDefaults.buttonColorsPrimary(),
                    modifier = Modifier.weight(1f),
                ) {
                    if (connecting) {
                        QingyuLoadingInButton()
                        Spacer(modifier = Modifier.width(8.dp))
                    }
                    Text(text = texts.confirmLabel)
                }
            }
            // S2：底部让位（系统手势区 + 16dp 呼吸）垫在**固定动作行之下**：
            // 垫进滚动区会在按钮上方造出一截永远空着的板（套件 KDoc「两种布局」口径）。
            Spacer(modifier = Modifier.height(bottomInset))
        }
    }
}

/**
 * 槽位单选按钮：选中 = 主色实心（`buttonColorsPrimary()`），未选中 = 默认次灰
 * （`buttonColors()`，`secondaryVariant` 底 + `onSecondaryVariant` 深字），
 * 与 Dart 的 `HyperosButtonVariant.primary` / `secondary` 对位。
 *
 * **不要**把未选中写成 `primarySurface` 底 + `primary` 字：没有 seed 时两者同色，
 * 标签不可见（2026-11-02 审核 P1）。
 *
 * 不用 `TextButton` 的理由同页面里的 `ActionButtonRow`：官方 `TextButtonColors`
 * 与 `ButtonColors` 不是同一个类型，混用编译不过。
 */
@Composable
private fun SlotButton(
    label: String,
    selected: Boolean,
    enabled: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Button(
        onClick = onClick,
        enabled = enabled,
        colors = if (selected) {
            ButtonDefaults.buttonColorsPrimary()
        } else {
            ButtonDefaults.buttonColors()
        },
        modifier = modifier,
    ) {
        Text(text = label)
    }
}
