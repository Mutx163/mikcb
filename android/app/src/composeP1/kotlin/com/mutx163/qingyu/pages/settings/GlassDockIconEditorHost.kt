package com.mutx163.qingyu.pages.settings

import android.util.Log
import android.widget.Toast
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import com.mutx163.qingyu.app.SettingsActionDispatcher
import com.mutx163.qingyu.app.TimetableSettingsModelStore

/**
 * 圆钮图标挑选页的真宿主：读 `glassDockButtonIconName`，选中后合并落盘并返回。
 *
 * ## 写回口径（Dart `settings_home_navigation.dart:200-218`）
 *
 * - 选中某个图标 → `copy(glassDockButtonIconName = name)`；
 * - 选「默认 加号」→ `copy(glassDockButtonIconName = null)`（Dart 用
 *   `copyWith(clearGlassDockButtonIconName: true)`，落盘都是同一键置空）；
 * - 与其它宿主一样**写完读回校验**：只有盘上真值等于新值才更新内存并返回，
 *   否则停在当前页提示「保存失败」（Dart 的 provider 落盘失败时也不会假装成功）。
 *
 * 这里不经过 `SettingsActionDispatcher.dispatch`：那套分派器按 `rowId` 白名单认动作，
 * 图标选择是「哪个名字」这种开放取值，新增一条 row 只会多一层转译。写盘仍走同一个
 * [TimetableSettingsModelStore]（读-合并-写，只覆盖本模型拥有的键），与其它设置页一致。
 *
 * ## 壳里怎么接
 *
 * `ShellPageIndex.kt` 的 `"b.glassDockIcon"` 目前仍指向通用 `SettingsHost`；请改成本宿主
 * （见交付说明里的白名单补丁表）。通用渲染层画不出搜索框 + 156 格网格。
 *
 * @param store 设置模型读写入口（壳里是 `wiring.settingsModel`）
 * @param onBack 返回上一页（选中成功后调用，对应 Dart 的 `Navigator.pop`）
 */
@Composable
fun GlassDockIconEditorHost(
    store: TimetableSettingsModelStore,
    onBack: () -> Unit,
) {
    val context = LocalContext.current
    var model by remember(store) { mutableStateOf(store.load()) }

    GlassDockIconPickerScreen(
        initialName = model.glassDockButtonIconName,
        onBack = onBack,
        onSelect = { name ->
            val next = model.copy(glassDockButtonIconName = name)
            store.save(next)
            val disk = runCatching { store.load() }.getOrNull()
            if (disk != null && SettingsActionDispatcher.persistLanded(model, next, disk)) {
                model = next
                onBack()
            } else {
                Log.e(LOG_TAG, "glass dock icon did not land: $name")
                Toast.makeText(
                    context,
                    SettingsStringsExt4.saveFailed.text,
                    Toast.LENGTH_SHORT,
                ).show()
            }
        },
    )
}

private const val LOG_TAG = "GlassDockIcon"
