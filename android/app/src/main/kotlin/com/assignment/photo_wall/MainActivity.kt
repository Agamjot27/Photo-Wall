package com.assignment.photo_wall

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val worker = Executors.newFixedThreadPool(3)
    private val mainHandler = Handler(Looper.getMainLooper())
    private var imageChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        imageChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.assignment.photowall/image",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "decodeDownsampled" -> worker.execute {
                        try {
                            val decoded = NativeImageMethods.decodeDownsampled(call.arguments)
                            mainHandler.post { result.success(decoded) }
                        } catch (error: IllegalArgumentException) {
                            mainHandler.post {
                                result.error("INVALID_ARGUMENTS", error.message, null)
                            }
                        } catch (error: Exception) {
                            mainHandler.post {
                                result.error("DECODE_FAILED", error.message, null)
                            }
                        }
                    }
                    "getMemoryInfo" -> result.success(NativeImageMethods.getMemoryInfo(this))
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onDestroy() {
        imageChannel?.setMethodCallHandler(null)
        worker.shutdownNow()
        super.onDestroy()
    }
}
