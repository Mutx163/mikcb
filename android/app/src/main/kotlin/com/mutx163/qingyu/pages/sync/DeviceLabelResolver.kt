package com.mutx163.qingyu.pages.sync

/**
 * 备份「设备名」的取值规则（用户 2026-11-10 报「为什么设备名叫 Compose 壳」）。
 *
 * 根因有两层：
 * 1. 壳层用 `configStore.readDeviceLabel() ?: "Compose 壳"`——开发期占位名漏换；
 * 2. 改名只写进了控制器草稿，**从未落盘**（`WebdavConfigStore.writeDeviceLabel` 生产零调用），
 *    所以读回来永远是空 ⇒ 永远显示占位名。
 *
 * 本对象只做纯计算（L0 可测），落盘由控制器经宿主注入的回调完成。
 *
 * 取值顺序对齐发布版：**用户存过的自定义名 > 设备型号 > 现成兜底文案（「本机」）**。
 *
 * ## 两处有意改良（不是发布版行为，别写成「对齐」）
 *
 * 1. **设备型号取代 hostname**：发布版默认用主机名（hostname）；本仓用
 *    `${Build.MANUFACTURER} ${Build.MODEL}`——中文用户更容易读懂，「小米 2201122C」
 *    比一串构建机名有信息量，也没有 hostname 在个别 ROM 上读不到的问题。
 * 2. **清空即写空串**：用户把设备名清空后提交，落盘写 `""`（存储层把空白归一成「未设置」），
 *    读取侧再回落设备型号 /「本机」。这是明确写过的状态，不是「从未设置」，
 *    展示上两者一致、行为可预期；已在契约测试登记。
 * 旧占位名视同「没有存过」——它不是用户起的名字。
 */
object DeviceLabelResolver {

    /**
     * 历史遗留占位名。
     *
     * 这个字面量**只允许出现在本文件**：源级守卫 `DeviceLabelLegacyPlaceholderGuardTest`
     * 会扫全仓 Kotlin 源码，别处再写一遍就红（防占位名回潮）。
     */
    const val LEGACY_PLACEHOLDER = "Compose 壳"

    /**
     * @param stored 存储里的设备名（可空；空白按未设置处理）
     * @param deviceModel 设备型号（`"${Build.MANUFACTURER} ${Build.MODEL}".trim()`，可空）
     * @param fallback 最后的兜底文案（现成 ARB：`SyncStrings.cloudBackupDefaultDeviceLabel`「本机」）
     */
    fun resolveDeviceLabel(
        stored: String?,
        deviceModel: String?,
        fallback: String,
    ): String {
        val storedTrimmed = stored?.trim().orEmpty()
        if (storedTrimmed.isNotEmpty() && storedTrimmed != LEGACY_PLACEHOLDER) {
            return storedTrimmed
        }
        val modelTrimmed = deviceModel?.trim().orEmpty()
        if (modelTrimmed.isNotEmpty()) {
            return modelTrimmed
        }
        return fallback
    }
}
