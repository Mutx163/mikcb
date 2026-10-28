package com.mutx163.qingyu.pages.transfer

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import com.mutx163.qingyu.share.qr.QrMatrix
import kotlin.math.floor
import kotlin.math.min

/** QR 规范要求的静默区宽度（模块数）：四周留白，否则摄像头贴边会读不到定位图形。 */
const val QR_QUIET_ZONE_MODULES = 4

/**
 * 把一个 [QrMatrix] 画到 Compose Canvas 上（Phase 3.5 · TQ1）。
 *
 * 这是发送页 `qrSlot` 槽位的渲染内核：`QrEncoder`（已交付）负责把帧文本编成矩阵，
 * 这里只负责把它画成**能扫得出来**的方块。
 *
 * ## 三个「画歪了就扫不出」的细节
 *
 * 1. **模块边长取整**：`module = floor(可用边长 / (size + 8))`。
 *    用浮点缩放会把相邻模块糊成灰边，MLKit 在灰边上判不清黑白，表现为
 *    「看起来有码、就是扫不出」——这类问题在真机上极难归因，所以宁可让二维码小一两像素；
 * 2. **必须黑码白底**：跟随深浅色主题把码画成浅色底/深色块，等于把对比度反过来，
 *    扫码库一律按「深色模块 = 1」判定。所以背景固定纯白、模块固定纯黑，不吃主题色；
 * 3. **四周留静默区**：白底要超出矩阵 [QR_QUIET_ZONE_MODULES] 个模块，且整块在容器里居中。
 *
 * ## 为什么按行合并连续黑块
 *
 * 一个 V20 的码是 97×97 ≈ 9400 个模块，逐个 `drawRect` 每 250ms 一次没必要。
 * 按行把连续黑块合成一个矩形，调用次数降到每行几个，画面上完全等价。
 */
@Composable
fun QrMatrixCanvas(matrix: QrMatrix, modifier: Modifier = Modifier) {
    Canvas(modifier = modifier) {
        val totalModules = matrix.size + QR_QUIET_ZONE_MODULES * 2
        val available = min(size.width, size.height)
        if (available <= 0f) return@Canvas
        // 取整：宁可少用一点边长，也不要模块边界落在半像素上。
        val module = floor(available / totalModules)
        if (module < 1f) {
            // 容器太小，一个模块分不到 1px：画出来只会是一团灰，不如直接不画。
            return@Canvas
        }
        val drawn = module * totalModules
        val left = (size.width - drawn) / 2f
        val top = (size.height - drawn) / 2f

        drawRect(color = Color.White, topLeft = Offset(left, top), size = Size(drawn, drawn))

        val originX = left + QR_QUIET_ZONE_MODULES * module
        val originY = top + QR_QUIET_ZONE_MODULES * module
        for (y in 0 until matrix.size) {
            var runStart = -1
            // 多扫一列（x == matrix.size）当作「亮」，好把行尾的黑块收尾。
            for (x in 0..matrix.size) {
                val dark = x < matrix.size && matrix.isDark(x, y)
                if (dark && runStart < 0) {
                    runStart = x
                } else if (!dark && runStart >= 0) {
                    drawRect(
                        color = Color.Black,
                        topLeft = Offset(originX + runStart * module, originY + y * module),
                        size = Size((x - runStart) * module, module),
                    )
                    runStart = -1
                }
            }
        }
    }
}
