package com.mutx163.qingyu.pages.guide

import com.mutx163.qingyu.app.KeyValueStore

/**
 * 启动引导要写的那几个**布尔标记**（与 Dart `StorageService` 逐字同一批键名）。
 *
 * ## 为什么单独一个类
 *
 * 「引导走完了」这件事在盘上只是一个 bool。写漏它，用户每次冷启动都被拉去重走一遍引导；
 * 写错**键名**，Dart 侧读不到、等同于没写。两种错都编译得过、测不出、真机上才看得见，
 * 所以键名集中在这里，`StartupFlowWiringTest` 会拿它跟 `lib/services/storage_service.dart`
 * 的实现逐字对拍。
 *
 * ## 键名对照（`storage_service.dart:29-32`，`flutter.` 前缀由 [KeyValueStore] 实现统一加）
 *
 * | 契约键 | Dart 常量 | 语义 |
 * |---|---|---|
 * | `has_completed_onboarding` | `_hasCompletedOnboardingKey` | 引导整体是否已走完（下次启动不再弹） |
 * | `has_handled_package_migration` | `_hasHandledPackageMigrationKey` | 换包名迁移引导是否已处理过 |
 *
 * ⚠️ `has_seen_user_guide` / `accepted_privacy_policy` **不在本类**：它们属于「用户指南」页
 * （`i.userGuide`）的职责，`main.dart:1474-1486` 是在指南退出时写的。本页只负责
 * 「开学日期 + 周数已落盘 + 引导整体完成」，不越界写别人的标记。
 */
class StartupFlowPreferences(private val store: KeyValueStore) {

    /** 引导是否已整体走完（Dart `hasCompletedOnboarding()`）。 */
    fun isOnboardingCompleted(): Boolean =
        store.getBool(KEY_COMPLETED_ONBOARDING, false)

    /** 标记引导已走完（Dart `setCompletedOnboarding(true)`）。 */
    fun markOnboardingCompleted() {
        store.putBool(KEY_COMPLETED_ONBOARDING, true)
    }

    /**
     * 回读校验：写完立刻读一遍，不一致返回 false。
     *
     * 为什么要这一步：Dart 侧 `setCompletedOnboarding` 自己就带这段防御
     * （`storage_service.dart:888-891`，注释写着「某些国产 ROM 的 commit() 可能不可靠」）。
     * 宿主据此决定要不要给用户一句实话，而不是假装写成功了。
     */
    fun markOnboardingCompletedAndVerify(): Boolean {
        markOnboardingCompleted()
        return isOnboardingCompleted()
    }

    companion object {
        /** Dart `_hasCompletedOnboardingKey`。 */
        const val KEY_COMPLETED_ONBOARDING = "has_completed_onboarding"

        /** Dart `_hasHandledPackageMigrationKey`（本页不写，留作对拍与后续接线用）。 */
        const val KEY_HANDLED_PACKAGE_MIGRATION = "has_handled_package_migration"
    }
}
