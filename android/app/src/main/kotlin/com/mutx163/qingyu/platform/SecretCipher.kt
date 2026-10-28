package com.mutx163.qingyu.platform

/**
 * 密钥加密缝（纯 Kotlin 接口，Android 实现在 [KeystoreSecretCipher]）。
 *
 * ## 为什么要抽成接口
 *
 * 「密码不许明文落盘」这条要求**必须能在 JVM 单测里被断言**。但真正的加密要用
 * Android KeyStore（`android.security.keystore.*`），JVM 单测里没有。
 * 抽成接口后：
 * - 生产走 [KeystoreSecretCipher]（平台密钥库，硬件支持时密钥不出 TEE/StrongBox）；
 * - 单测注入一个「一定改变内容」的替身，于是**「落盘字节里不含明文」这条断言可以在
 *   JVM 上跑**（见 `WebdavConfigStoreImplTest`）。
 *
 * 真正的密钥库路径只能在真机上验（见认领文件的真机对照清单），这里不假装。
 */
interface SecretCipher {

    /** 明文 → 可落盘的密文。实现**必须**保证输出与输入不同（同则抛错）。 */
    fun encrypt(plaintext: String): String

    /**
     * 密文 → 明文。
     *
     * **解不开返回 null，不抛**：密钥失效在本仓是**已知会发生**的故障
     * （换机恢复、系统升级、用户凭证变化——Dart 侧 `webdav_sync_credentials_store.dart:41-56`
     * 专门为此写了容错）。调用方一律把 null 理解成「没存过密码」，引导用户重新输入；
     * 抛异常会把整个配置加载炸成「未连接 + 配置框全空」。
     */
    fun decrypt(ciphertext: String): String?
}
