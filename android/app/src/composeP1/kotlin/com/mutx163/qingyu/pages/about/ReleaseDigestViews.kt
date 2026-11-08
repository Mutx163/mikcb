package com.mutx163.qingyu.pages.about

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.theme.Colors
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 鍒嗙被鑳跺泭宸︽爮鐨勬渶灏忓搴︼細11sp 涓や釜姹夊瓧锛?2dp锛? 6dp脳2 妯悜鍐呰竟璺?= 34dp銆? * 娌℃爣绛剧殑琛岄潬瀹冨崰浣忓悓涓€鏍忥紝淇濊瘉鎵€鏈夐噸鐐硅鐨勬爣棰樹粠鍚屼竴鏉＄珫绾垮紑濮嬨€? */
private val LabelChipMinWidth = 34.dp
private val biteProbe: Int = "x"

/**
 * 鍙戝竷璇存槑鎽樿鐨?*鍏变韩娓叉煋浠?*锛?026-11-03 鐗堥潰鏀跺彛锛夈€? *
 * 銆屾洿鏂版棩蹇楅〉銆嶏紙[ChangelogPage]锛変笌銆岀増鏈洿鏂伴〉銆嶏紙[AboutUpdatePage]锛夋鍓嶅悇鍐欎竴濂? * 鍑犱箮鐩稿悓鐨勭鏈夊疄鐜帮紙HighlightRow / GroupedEntries / ExpandToggle / kindColor锛夆€斺€? * 琛岃窛銆佸渾鐐广€佸垎绫昏壊銆佸睍寮€鏂囨鍚勮嚜婕傜Щ銆傛湰鏂囦欢鏀舵垚鍞竴涓€濂楋紝涓ら〉鍏辩敤锛? *
 * - [ReleaseNotesHighlightRow]锛氫竴鏉°€屾洿鏂伴噸鐐广€嶏紙鍒嗙被鑹茬偣 + 鍒嗙被鏍囩 + 鐭爣棰橈級锛? * - [ReleaseNotesGroupedEntries]锛氬睍寮€鍖烘寜鍒嗙被鍒嗙粍鐨勫畬鏁存潯鐩紱
 * - [ReleaseNotesExpandToggle]锛氬睍寮€/鏀惰捣鍏ュ彛锛堟枃妗堝鐢?[ChangelogStrings] 鏃㈡湁 ARB 閿紝闆舵柊澧烇級锛? * - [releaseNotesKindColor]锛氬垎绫昏壊璇箟锛堟柊澧?涓婚鑹?/ 绉婚櫎=閿欒鑹?/ 鍏朵綑娆＄骇澧ㄨ壊锛夈€? *
 * 瀛楀彿涓€寰嬭蛋 [MiuixTheme.textStyles]锛圼shiftWeight] 鍙仛澧為噺锛夛紝棰滆壊鍏ㄩ儴鏉ヨ嚜涓婚
 * 鈥斺€旀湰鏂囦欢涓嶅嚭鐜板啓姝诲瓧鍙蜂笌瑁歌壊鍊笺€? */

/** 鏉＄洰鍒嗙粍鐨勫浐瀹氶『搴忥紙涓庢寫閫夐噸鐐圭殑浼樺厛绾т竴鑷达紝Dart `_groupOrder`锛夈€?*/
internal val releaseNotesGroupOrder = listOf(
    ReleaseChangeKind.ADDED,
    ReleaseChangeKind.IMPROVED,
    ReleaseChangeKind.REMOVED,
    ReleaseChangeKind.FIXED,
    ReleaseChangeKind.OTHER,
)

/** 鍒嗙被鑹诧細鏂板鐢ㄤ富棰樿壊锛堜竴鐗堥噷鏈€甯屾湜琚湅鍒扮殑灏辨槸瀹冿級锛岀Щ闄ょ敤閿欒鑹诧紝鍏朵綑娆＄骇澧ㄨ壊銆?*/
internal fun releaseNotesKindColor(kind: ReleaseChangeKind, colors: Colors): Color = when (kind) {
    ReleaseChangeKind.ADDED -> colors.primary
    ReleaseChangeKind.REMOVED -> colors.error
    ReleaseChangeKind.IMPROVED, ReleaseChangeKind.FIXED -> colors.onSurfaceSecondary
    ReleaseChangeKind.OTHER -> colors.onSurfaceVariantSummary
}

/**
 * 涓€鏉°€屾洿鏂伴噸鐐广€嶏細鍒嗙被鏍囩锛堝彲閫夛級+ 鐭爣棰橈紙鏈€澶氫袱琛岋級銆? *
 * @param useLabelChip 鍒嗙被鏍囩鏄惁鍋氭垚**娣¤壊鑳跺泭**锛堝垎绫昏壊 12% 搴?+ 鍒嗙被鑹插瓧锛夛紝
 *   榛樿 `false` 淇濇寔銆屽渾鐐?+ 褰╄壊鏂囧瓧銆嶇殑鍏嬪埗褰㈡€併€傛洿鏂伴〉鍙睍绀轰竴鐗堝唴瀹广€佹潯鐩皯锛? *   鑳跺泭鑳芥妸銆屾柊澧?/ 浼樺寲銆嶈繖涓ょ璇箟鍒嗗紑锛涙洿鏂版棩蹇楅〉涓€灞忓崄鍑犵増锛岃兌鍥婁細鍙樻垚鍣０锛? *   鎵€浠ョ敱璋冪敤椤佃嚜宸遍€夛紝涓嶇粺涓€鏀广€? */
@Composable
internal fun ReleaseNotesHighlightRow(
    entry: ReleaseChangeEntry,
    useLabelChip: Boolean = false,
) {
    val colors = MiuixTheme.colorScheme
    val accent = releaseNotesKindColor(entry.kind, colors)
    Row(
        modifier = Modifier.fillMaxWidth().padding(bottom = 10.dp),
        verticalAlignment = Alignment.Top,
    ) {
        if (useLabelChip) {
            // 鍥哄畾鏈€灏忓搴︼細娌℃湁鍒嗙被鏍囩鐨勮锛堣€佹牸寮忥紝鎴栧０鏄庣殑閲嶇偣瀵逛笉涓婃鏂囷級涔熷崰浣忓悓涓€鏍忥紝
            // 鍚﹀垯宸︾紭浼氭帓鎴愩€岃兌鍥?/ 鍦嗙偣 / 鑳跺泭銆嶄笁妗ｏ紝鏁村紶鍗＄湅鐫€鍍忔病瀵归綈銆?            Row(modifier = Modifier.widthIn(min = LabelChipMinWidth)) {
                if (entry.label.isNotEmpty()) {
                    Text(
                        text = entry.label,
                        style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.MEDIUM),
                        color = accent,
                        maxLines = 1,
                        modifier = Modifier
                            .background(accent.copy(alpha = 0.12f), RoundedCornerShape(6.dp))
                            .padding(horizontal = 6.dp, vertical = 2.dp),
                    )
                }
            }
            Spacer(Modifier.width(8.dp))
        } else {
            Spacer(
                modifier = Modifier
                    .padding(top = 7.dp)
                    .size(5.dp)
                    .background(accent, CircleShape),
            )
            Spacer(Modifier.width(8.dp))
            if (entry.label.isNotEmpty()) {
                Text(
                    text = entry.label,
                    style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                    color = accent,
                )
                Spacer(Modifier.width(8.dp))
            }
        }
        Text(
            text = entry.headline,
            style = MiuixTheme.textStyles.body2,
            color = colors.onBackground,
            lineHeight = 19.sp,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
    }
}

/** 灞曞紑鍖烘寜鍒嗙被鍒嗙粍锛氭爣棰樺舰濡傘€屾柊澧?路 12銆嶏紝鏉＄洰鏈韩涓嶅啀閲嶅鍒嗙被璇嶃€?*/
@Composable
internal fun ReleaseNotesGroupedEntries(digest: ReleaseNotesDigest) {
    val colors = MiuixTheme.colorScheme
    var isFirstGroup = true

    for (kind in releaseNotesGroupOrder) {
        val group = digest.entries.filter { it.kind == kind }
        if (group.isEmpty()) continue
        if (!isFirstGroup) Spacer(Modifier.height(12.dp))
        isFirstGroup = false

        val label = group.firstOrNull { it.label.isNotEmpty() }?.label
        if (label != null) {
            Text(
                text = "$label 路 ${group.size}",
                style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                color = releaseNotesKindColor(kind, colors),
            )
            Spacer(Modifier.height(6.dp))
        }
        for (entry in group) {
            ReleaseNotesEntryRow(entry)
        }
    }
}

/** 灞曞紑鍚庣殑涓€鏉″畬鏁存潯鐩紙璇存槑鏂囧瓧寮辫壊銆佸畬鏁存姌琛岋級銆?*/
@Composable
internal fun ReleaseNotesEntryRow(entry: ReleaseChangeEntry) {
    val colors = MiuixTheme.colorScheme
    Text(
        text = entry.text,
        style = MiuixTheme.textStyles.footnote1,
        color = colors.onSurfaceSecondary,
        lineHeight = 20.sp,
        modifier = Modifier.padding(bottom = 10.dp),
    )
}

/**
 * 灞曞紑/鏀惰捣鍏ュ彛锛氱函鏂囧瓧鍔ㄤ綔 + 绠ご銆傛枃妗堝鐢ㄦ洿鏂版棩蹇楅〉鍚屼竴缁?ARB 閿€斺€? * 銆屾敹璧?/ 鏌ョ湅鍏ㄩ儴 N 椤?/ 鏌ョ湅瀹屾暣璇存槑銆嶇殑鍒ゆ嵁涓ら〉蹇呴』涓€瀛椾笉宸€? */
@Composable
internal fun ReleaseNotesExpandToggle(
    expanded: Boolean,
    revealsHiddenEntries: Boolean,
    total: Int,
    onToggle: () -> Unit,
) {
    val colors = MiuixTheme.colorScheme
    val label = when {
        expanded -> ChangelogStrings.collapseAction
        revealsHiddenEntries -> ChangelogStrings.viewAllAction(total)
        else -> ChangelogStrings.viewFullAction
    }

    Row(
        // 瑙嗚楂樺害涓嶅彉锛岄潬 40dp 鏈€灏忛珮搴︽妸鐑尯琛ュ埌鍙偣灏哄害锛堝師 26dp 鎵嬫寚鎸変笉鍑嗭級銆?        modifier = Modifier.clickable { onToggle() }.heightIn(min = 40.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = label,
            style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.SEMIBOLD),
            color = colors.primary,
        )
        Spacer(Modifier.width(2.dp))
        // 鐢ㄧ湡姝ｇ殑绠ご锛堟棆杞?90掳锛夛細瀹樻柟 `ExpandMore` 鏄竴鏋氥€屾柟瑙掑睍寮€銆嶅浘鏍囷紝
        // 16dp 涓嬬湅鐫€鍍忎釜绌烘柟妗嗭紝浼氳浜轰互涓哄瓧褰㈡病鍔犺浇鍑烘潵銆?        Icon(
            imageVector = MiuixIcons.ChevronForward,
            contentDescription = null,
            tint = colors.primary,
            modifier = Modifier.size(14.dp).rotate(if (expanded) -90f else 90f),
        )
    }
}

/**
 * 闀挎枃鎽樿鐨勭粺涓€褰㈡€侊細閲嶇偣 + 璁℃暟甯告樉锛屽畬鏁存潯鐩?*榛樿鏀惰捣**銆佺偣寮€鎵嶉摵寮€
 * 锛堛€屽埆涓€鍧ㄧ伆瀛楀爢鐫€銆嶏級銆傚垎闅旂嚎鐢ㄤ富棰?secondaryContainer 鐨?1dp 娣＄嚎锛? * 涓庢洿鏂版棩蹇楅〉鍚屾锛涙槸鍚﹀睍寮€鐢辫皟鐢ㄦ柟鎸佹湁鐘舵€併€? */
@Composable
internal fun ReleaseNotesExpandableBody(digest: ReleaseNotesDigest) {
    val colors = MiuixTheme.colorScheme
    var expanded by remember(digest) { mutableStateOf(false) }
    val hasHiddenEntries = digest.total > digest.highlights.size

    if (digest.entries.isNotEmpty()) {
        Spacer(Modifier.height(4.dp))
        ReleaseNotesExpandToggle(
            expanded = expanded,
            revealsHiddenEntries = hasHiddenEntries,
            total = digest.total,
            onToggle = { expanded = !expanded },
        )
    }

    if (expanded) {
        Spacer(Modifier.height(10.dp))
        Spacer(
            modifier = Modifier
                .fillMaxWidth()
                .height(1.dp)
                .background(colors.secondaryContainer),
        )
        Spacer(Modifier.height(10.dp))
        ReleaseNotesGroupedEntries(digest)
    }
}
