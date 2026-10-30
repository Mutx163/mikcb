package com.mutx163.qingyu.pages.import.warehouse

/**
 * 仓库列表页的「这一屏到底在干嘛」（8b 新增，供 `g2.warehouseImport` / `g2.schoolAdapters` 共用）。
 *
 * ## 为什么需要它
 *
 * 这两个页面原来只有一个空列表状态，文案写死成「暂无可用学校」/「暂时无法读取适配器列表」。
 * 接上真仓库以后，空列表有三种完全不同的含义，**混成一句就是骗用户**：
 *
 * | 相位 | 用户看到 | 真实原因 |
 * |---|---|---|
 * | [Loading] | 转圈 | 请求还在路上 |
 * | [Failed] | 失败标题 + 重试按钮 | 全候选都失败 / 文件解析不出学校 |
 * | [Idle] | 空态文案 | 请求成功但确实没有内容 |
 *
 * 默认值 [Idle] 是给「壳里还没接数据层的调用点」用的：它们传空列表，看到的行为与改动前一致。
 */
enum class WarehouseListPhase {
    Idle,
    Loading,
    Failed,
}
