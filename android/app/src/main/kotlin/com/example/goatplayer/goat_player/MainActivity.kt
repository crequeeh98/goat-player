package com.example.goatplayer.goat_player

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.view.OrientationEventListener
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.goatplayer/updater"
    private var orientationEventListener: OrientationEventListener? = null
    private var methodChannel: MethodChannel? = null
    private var lastReportedOrientation: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = channel

        orientationEventListener?.disable()
        orientationEventListener = object : OrientationEventListener(this) {
            override fun onOrientationChanged(orientation: Int) {
                if (orientation == ORIENTATION_UNKNOWN) return
                val newOrientation = when {
                    orientation in 0..35 || orientation in 325..359 -> "portrait"
                    orientation in 235..305 -> "landscapeLeft"
                    orientation in 55..125 -> "landscapeRight"
                    else -> null
                } ?: return

                if (lastReportedOrientation == null) {
                    lastReportedOrientation = newOrientation
                    return
                }
                val prevIsLandscape = lastReportedOrientation?.startsWith("landscape") == true
                val newIsLandscape = newOrientation.startsWith("landscape")
                if (prevIsLandscape != newIsLandscape || (newIsLandscape && lastReportedOrientation != newOrientation)) {
                    lastReportedOrientation = newOrientation
                    runOnUiThread {
                        methodChannel?.invokeMethod("onDeviceOrientationChanged", newOrientation)
                    }
                }
            }
        }
        if (orientationEventListener?.canDetectOrientation() == true) {
            orientationEventListener?.enable()
        }

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getSupportedAbis" -> {
                    result.success(Build.SUPPORTED_ABIS.toList())
                }
                "isTvDevice" -> {
                    val uiModeManager = getSystemService(android.content.Context.UI_MODE_SERVICE) as? android.app.UiModeManager
                    val isTv = uiModeManager?.currentModeType == android.content.res.Configuration.UI_MODE_TYPE_TELEVISION
                        || packageManager.hasSystemFeature("android.software.leanback")
                        || packageManager.hasSystemFeature("android.hardware.type.television")
                        || packageManager.hasSystemFeature("amazon.hardware.fire_tv")
                    result.success(isTv)
                }
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath == null) {
                        result.error("INVALID_PATH", "File path is null", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val file = File(filePath)
                        if (!file.exists()) {
                            result.error("FILE_NOT_FOUND", "APK file does not exist", null)
                            return@setMethodCallHandler
                        }
                        val contentUri: Uri = FileProvider.getUriForFile(
                            this,
                            "${applicationContext.packageName}.fileprovider",
                            file
                        )
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(contentUri, "application/vnd.android.package-archive")
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTALL_ERROR", e.localizedMessage, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onDestroy() {
        orientationEventListener?.disable()
        orientationEventListener = null
        methodChannel = null
        super.onDestroy()
    }
}
