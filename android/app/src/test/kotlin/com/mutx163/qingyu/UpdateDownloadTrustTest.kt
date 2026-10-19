package com.mutx163.qingyu

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 系统下载器 URL 信任根（2026-10-19 审计 #24）。
 *
 * 只放行官方直连 GitHub / GitCode（含子域与 githubusercontent.com 302 落点域）；
 * http、第三方主机、镜像外壳、畸形输入一律拒绝。
 */
class UpdateDownloadTrustTest {
    @Test
    fun acceptsOfficialDirectUrls() {
        assertTrue(
            isTrustedSystemDownloadUrl(
                "https://github.com/Mutx163/mikcb/releases/download/v2.1.4/mikcb.apk",
            ),
        )
        assertTrue(
            isTrustedSystemDownloadUrl(
                "https://gitcode.com/mutx/qingyu/releases/download/v2.1.4/mikcb.apk",
            ),
        )
        // GitHub release 资产 302 的真实落点域（签名短链）。
        assertTrue(
            isTrustedSystemDownloadUrl(
                "https://objects.githubusercontent.com/assets/x?token=1",
            ),
        )
        assertTrue(
            isTrustedSystemDownloadUrl(
                "https://raw.githubusercontent.com/Mutx163/mikcb/main/x",
            ),
        )
    }

    @Test
    fun rejectsNonHttpsAndForeignHosts() {
        assertFalse(
            isTrustedSystemDownloadUrl(
                "http://github.com/Mutx163/mikcb/releases/download/v2.1.4/mikcb.apk",
            ),
        )
        assertFalse(isTrustedSystemDownloadUrl("https://evil.com/mikcb.apk"))
        // 伪造域名不能靠后缀匹配混进来。
        assertFalse(isTrustedSystemDownloadUrl("https://github.com.evil.com/mikcb.apk"))
        assertFalse(isTrustedSystemDownloadUrl("https://evil-github.com/mikcb.apk"))
        // 镜像外壳只服务应用内下载通道，系统下载器不接受。
        assertFalse(
            isTrustedSystemDownloadUrl(
                "https://ghfast.top/https://github.com/Mutx163/mikcb/x.apk",
            ),
        )
    }

    @Test
    fun rejectsMalformedInput() {
        assertFalse(isTrustedSystemDownloadUrl(""))
        assertFalse(isTrustedSystemDownloadUrl("not a url"))
        assertFalse(isTrustedSystemDownloadUrl("file:///sdcard/x.apk"))
        assertFalse(isTrustedSystemDownloadUrl("https:///no-host/x.apk"))
    }
}
