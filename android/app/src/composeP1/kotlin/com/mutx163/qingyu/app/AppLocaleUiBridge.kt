package com.mutx163.qingyu.app

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/**
 * 语言切换的 UI 桥：把 [AppLocaleRuntime] 的普通字段接到 Compose 的 snapshot state。
 *
 * ## 为什么需要它
 *
 * `app/` 是纯 Kotlin 层（`AppLayerPurityTest` 守着，L0 直接 kotlinc 跑真 JVM），
 * 不能 import Compose；但语言切换又必须让**正在显示的**文案当场重组，而不是重建整棵壳
 * （重建会丢返回栈，用户从设置页切语言会被弹回首页）。
 *
 * 做法：`AppLocaleRuntime.text()` 每次取值先调用 `revisionReader()`。这里把
 * `revisionReader` 接到 snapshot state 上——Composable 里取文案时自然登记为观察者；
 * 语言一变，`onLocaleChanged` 把 state 自增，所有读文案的 Composable 自动重组，
 * 导航栈、滚动位置、表单草稿都保留。
 *
 * ## 边界
 *
 * - 只做状态中转，不参与语言解析；
 * - `install()` 幂等，重复调用只是覆盖同一组钩子；
 * - 单测不装桥：`revisionReader` 默认返回 0，行为与纯 Kotlin 完全一致。
 */
object AppLocaleUiBridge {

    private var revision by mutableStateOf(0)

    /** 幂等安装：进程内调用一次即可（重复调用无副作用）。 */
    fun install() {
        AppLocaleRuntime.revisionReader = { revision }
        AppLocaleRuntime.onLocaleChanged = { revision++ }
    }
}
