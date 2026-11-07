package com.mutx163.qingyu.pages.transfer

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.BarcodeScanner
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import com.mutx163.qingyu.share.camera.BarcodeFormat
import com.mutx163.qingyu.share.camera.BarcodePoint
import com.mutx163.qingyu.share.camera.BarcodeScanResult
import com.mutx163.qingyu.share.camera.PermissionAction
import com.mutx163.qingyu.share.camera.PermissionState
import com.mutx163.qingyu.share.camera.ScanPipeline
import com.mutx163.qingyu.theme.QingyuTheme
import java.util.concurrent.Executors
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 二维码扫码页的相机宿主槽位（Phase 3.5 · P35-B6）。
 *
 * ## 为什么这个文件在 `composeP1/` 而不是 `main/`
 *
 * CameraX 与 MLKit 的依赖只挂在 compose 变体上（`build.gradle` 里刻意没挂
 * `implementation`，免得 Flutter 正式包白背一份解码模型）。`main/` 是所有变体共用的源集，
 * 把这套依赖放进去会让正式包直接编译失败。所以：**决策在 `main/`（B5），胶水在这里**。
 *
 * ## 一条帧的完整路径
 *
 * ```
 * CameraX PreviewView（预览）
 *   └─ ImageAnalysis（STRATEGY_KEEP_ONLY_LATEST，永远只解最新一帧，不排队积压）
 *        └─ QrCameraAnalyzer.analyze
 *             ├─ coordinator.beginFrame(now)  ← 权限 + 100ms 节流两道闸；false 直接 close() 丢帧
 *             ├─ MLKit BarcodeScanning.process(InputImage)   ← 异步
 *             └─ onSuccess: Barcode → BarcodeScanResult
 *                  └─ coordinator.deliverDecoded(result)     ← 去重 + 跨码防抖
 *                       └─ onBarcode(...)                    ← 交给页面/业务
 * ```
 *
 * 权限走 B5 的 `CameraPermissionStateMachine`（经由 [QrScanSessionCoordinator] 透传），
 * 本文件只把 [PermissionAction] 翻译成 Android 动作：弹系统框 / 跳应用设置。
 *
 * ## 生命周期
 *
 * `ProcessCameraProvider` 绑到宿主的 lifecycle；**离开页面（组合销毁）就 `unbindAll()`**。
 * 不解绑的后果不是「卡一下」，而是离开后相机一直占着——用户会看到相机指示灯不灭，
 * 且别的 App 打不开相机。
 */
@Composable
fun QrCameraSlot(
    onBarcode: (BarcodeScanResult) -> Unit,
    modifier: Modifier = Modifier,
    active: Boolean = true,
) {
    val context = LocalContext.current
    val activity = remember(context) { context.findHostActivity() }
    val coordinator = remember {
        QrScanSessionCoordinator(
            ScanPipeline(initialHasPermission = hasCameraPermission(context)),
        )
    }
    var permissionState by remember { mutableStateOf(coordinator.permissionState) }

    val permissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission(),
    ) { granted ->
        val shouldShowRationale = activity?.let {
            ActivityCompat.shouldShowRequestPermissionRationale(it, Manifest.permission.CAMERA)
        } ?: false
        permissionState = coordinator.onPermissionResult(granted, shouldShowRationale)
    }

    // 进页面先问一次：状态机会决定这是「弹系统框」「先解释」还是「只能去设置」。
    LaunchedEffect(Unit) {
        if (!coordinator.isPermissionGranted) {
            permissionState = requestCameraPermission(coordinator, activity, permissionLauncher::launch)
        }
    }

    // 从系统设置（或别处）回到前台时自愈：用户在设置里开了/关了权限，这里跟上真实状态。
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                permissionState = coordinator.onHostResumed(hasCameraPermission(context))
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    if (permissionState == PermissionState.GRANTED) {
        CameraPreview(
            coordinator = coordinator,
            onBarcode = onBarcode,
            modifier = modifier,
            active = active,
        )
    } else {
        // 没有权限：不画假预览，把「为什么没有画面」直接说给用户。
        // 文案复用 B5 状态机自带的 rationale（不在渲染层另写一套，避免与 ARB 分叉）。
        PermissionHint(
            message = coordinator.rationaleMessage,
            modifier = modifier,
            onClick = {
                permissionState = requestCameraPermission(
                    coordinator = coordinator,
                    activity = activity,
                    launchSystemDialog = permissionLauncher::launch,
                )
            },
        )
    }
}

/**
 * 「扫码页 + 真相机」的一行接线。
 *
 * 页面本身（[QrTransferScanPage]）把相机做成槽位参数，为的是「宿主决定相机长什么样」。
 * 本机宿主就是这里：CameraX 预览 + MLKit 解码。
 */
@Composable
fun QrScanPageWithCamera(
    model: QrTransferScanModel,
    onBack: () -> Unit,
    onRestart: () -> Unit,
    onImportFullBackup: () -> Unit,
    onBarcode: (BarcodeScanResult) -> Unit,
) {
    QrTransferScanPage(
        model = model,
        onBack = onBack,
        onRestart = onRestart,
        onImportFullBackup = onImportFullBackup,
        cameraSlot = { QrCameraSlot(onBarcode = onBarcode) },
    )
}

// ─────────────────────────────────────────────────────────────
// 权限
// ─────────────────────────────────────────────────────────────

/**
 * 按 B5 状态机给出的动作执行权限申请。
 *
 * @return 执行后状态机的最新状态（供 Compose 重绘）。
 */
private fun requestCameraPermission(
    coordinator: QrScanSessionCoordinator,
    activity: Activity?,
    launchSystemDialog: (String) -> Unit,
): PermissionState {
    when (coordinator.onPermissionRequested()) {
        // 首次申请，或用户已看过理由后再申请：都直接交给系统弹窗。
        PermissionAction.Request, is PermissionAction.ShowRationale ->
            if (activity != null) launchSystemDialog(Manifest.permission.CAMERA)

        // 永久拒绝：系统弹窗不会再出现了，只能把用户送到应用详情页自己开。
        PermissionAction.OpenSettings -> openAppSettings(activity)

        PermissionAction.None -> Unit
    }
    return coordinator.permissionState
}

private fun hasCameraPermission(context: Context): Boolean =
    ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) ==
        PackageManager.PERMISSION_GRANTED

private fun openAppSettings(activity: Activity?) {
    if (activity == null) return
    val intent = Intent(
        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
        Uri.fromParts("package", activity.packageName, null),
    )
    try {
        activity.startActivity(intent)
    } catch (_: Exception) {
        // 个别定制 ROM 没有应用详情页：不崩，用户可自己去系统设置里开。
    }
}

/** 在 ContextWrapper 链上找 Activity（Compose 里拿不到 Activity 时的常规做法）。 */
private fun Context.findHostActivity(): Activity? {
    var current: Context? = this
    while (current is ContextWrapper) {
        if (current is Activity) return current
        current = current.baseContext
    }
    return null
}

@Composable
private fun PermissionHint(
    message: String,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    Box(
        modifier = modifier
            .fillMaxSize()
            .clickable(onClick = onClick)
            .padding(24.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = message,
            style = MiuixTheme.textStyles.body2,
            // 原本写死两张灰（0xFFB0B0B8 / 0xFF5A5A62）：换主题色或深色模式下与
            // 周围字色不一致，且样式守卫抓不到 `Color(if (...)` 这种形态。
            color = Color(QingyuTheme.secondaryText(dark)),
        )
    }
}

// ─────────────────────────────────────────────────────────────
// 相机预览 + 帧分析
// ─────────────────────────────────────────────────────────────

@Composable
private fun CameraPreview(
    coordinator: QrScanSessionCoordinator,
    onBarcode: (BarcodeScanResult) -> Unit,
    modifier: Modifier = Modifier,
    active: Boolean,
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val currentOnBarcode by rememberUpdatedState(onBarcode)
    val previewView = remember(context) {
        PreviewView(context).apply {
            // COMPATIBLE 走 TextureView：在 Compose 里叠放/圆角裁切更稳，
            // PERFORMANT 的 SurfaceView 会被部分 ROM 的图层合成吃掉圆角。
            implementationMode = PreviewView.ImplementationMode.COMPATIBLE
        }
    }
    // 绑定失败不能只留黑屏：明确告诉用户相机被占用，并给一个重试入口。
    var bindFailed by remember { mutableStateOf(false) }
    // 点「重试」时自增，作为 DisposableEffect 的 key 重新走一遍绑定。
    var bindAttempt by remember { mutableStateOf(0) }

    DisposableEffect(active, lifecycleOwner, bindAttempt) {
        if (!active) {
            bindFailed = false
            return@DisposableEffect onDispose { }
        }
        var provider: ProcessCameraProvider? = null
        var analyzer: QrCameraAnalyzer? = null
        var disposed = false
        val analysisExecutor = Executors.newSingleThreadExecutor()
        val providerFuture = ProcessCameraProvider.getInstance(context)

        val bindListener = Runnable {
            if (disposed) return@Runnable
            try {
                val cameraProvider = providerFuture.get()

                val preview = Preview.Builder().build().also {
                    it.setSurfaceProvider(previewView.surfaceProvider)
                }
                val imageAnalysis = ImageAnalysis.Builder()
                    // 只保留最新一帧：解码比相机慢时宁可丢帧，也不要让用户对着「几秒前的画面」扫码。
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .build()
                val frameAnalyzer = QrCameraAnalyzer(coordinator) { result -> currentOnBarcode(result) }
                analyzer = frameAnalyzer
                imageAnalysis.setAnalyzer(analysisExecutor, frameAnalyzer)

                cameraProvider.unbindAll()
                cameraProvider.bindToLifecycle(
                    lifecycleOwner,
                    CameraSelector.DEFAULT_BACK_CAMERA,
                    preview,
                    imageAnalysis,
                )
                provider = cameraProvider
                bindFailed = false
            } catch (_: Exception) {
                // 相机被占用 / 无可用后摄：渲染层换成可见提示 + 重试，不把整页带崩。
                bindFailed = true
            }
        }
        providerFuture.addListener(bindListener, ContextCompat.getMainExecutor(context))

        onDispose {
            disposed = true
            provider?.unbindAll()
            analyzer?.close()
            analysisExecutor.shutdown()
        }
    }

    Box(modifier = modifier) {
        AndroidView(factory = { previewView }, modifier = Modifier.fillMaxSize())
        if (bindFailed) {
            CameraBindFailedHint(
                onRetry = {
                    bindFailed = false
                    bindAttempt++
                },
                modifier = Modifier.fillMaxSize(),
            )
        }
    }
}

/** 相机绑定失败的可见提示：说清原因，并保留重试入口（不是一句死字）。 */
@Composable
private fun CameraBindFailedHint(
    onRetry: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .background(MiuixTheme.colorScheme.surface)
            .padding(24.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = TransferStrings.qrTransferCameraUnavailable.text,
            style = MiuixTheme.textStyles.body2,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(16.dp))
        Button(onClick = onRetry) {
            Text(text = TransferStrings.qrTransferCameraRetry.text)
        }
    }
}

/**
 * 帧分析器：把 CameraX 的帧转成 MLKit 能吃的 [InputImage]，解码后交给协调器判去留。
 *
 * 注意 `image.close()` 的位置：必须在 MLKit 的完成回调里关（提前关会让解码拿到已释放的缓冲，
 * 表现为「偶尔能扫到、多数帧崩在 native`）。
 */
private class QrCameraAnalyzer(
    private val coordinator: QrScanSessionCoordinator,
    private val onBarcode: (BarcodeScanResult) -> Unit,
) : ImageAnalysis.Analyzer {

    private val scanner: BarcodeScanner = BarcodeScanning.getClient(
        BarcodeScannerOptions.Builder()
            .setBarcodeFormats(Barcode.FORMAT_QR_CODE)
            .build(),
    )

    @androidx.camera.core.ExperimentalGetImage
    override fun analyze(image: ImageProxy) {
        val now = coordinator.pipeline.clock.currentTimeMillis()
        if (!coordinator.beginFrame(now)) {
            // 被节流/权限拦下：这一帧根本不解码，直接还给相机。
            image.close()
            return
        }
        val mediaImage = image.image
        if (mediaImage == null) {
            coordinator.endFrame(now)
            image.close()
            return
        }
        val input = InputImage.fromMediaImage(mediaImage, image.imageInfo.rotationDegrees)
        scanner.process(input)
            .addOnSuccessListener { barcodes ->
                val result = barcodes.firstNotNullOfOrNull { it.toScanResult(now) }
                if (result != null) {
                    coordinator.deliverDecoded(result)?.let(onBarcode)
                }
            }
            .addOnCompleteListener {
                coordinator.endFrame(coordinator.pipeline.clock.currentTimeMillis())
                image.close()
            }
    }

    /** 释放 MLKit 客户端（页面离开时调用）。 */
    fun close() {
        scanner.close()
    }
}

/** MLKit 的 `Barcode` → 纯逻辑 [BarcodeScanResult]（宿主层唯一允许 import 第三方类型的地方）。 */
private fun Barcode.toScanResult(timestampMs: Long): BarcodeScanResult? {
    val value = rawValue ?: displayValue ?: return null
    return BarcodeScanResult(
        rawValue = value,
        format = when (format) {
            Barcode.FORMAT_QR_CODE -> BarcodeFormat.QR_CODE
            Barcode.FORMAT_CODE_128 -> BarcodeFormat.CODE_128
            Barcode.FORMAT_CODE_39 -> BarcodeFormat.CODE_39
            Barcode.FORMAT_EAN_13 -> BarcodeFormat.EAN_13
            Barcode.FORMAT_EAN_8 -> BarcodeFormat.EAN_8
            Barcode.FORMAT_DATA_MATRIX -> BarcodeFormat.DATA_MATRIX
            else -> BarcodeFormat.UNKNOWN
        },
        rawBytes = rawBytes,
        cornerPoints = cornerPoints
            ?.filterNotNull()
            ?.map { BarcodePoint(it.x.toFloat(), it.y.toFloat()) }
            ?: emptyList(),
        timestampEpochMs = timestampMs,
    )
}
