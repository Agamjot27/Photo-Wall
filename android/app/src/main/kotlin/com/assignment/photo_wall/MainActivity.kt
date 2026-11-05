package com.assignment.photo_wall

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CancellationException
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {
    private val worker = Executors.newFixedThreadPool(3)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val cancellations = ConcurrentHashMap<Int, AtomicBoolean>()
    private var imageChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        imageChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.assignment.photowall/image",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "decodeDownsampled" -> {
                        val requestId = (call.arguments as? Map<*, *>)?.get("requestId") as? Int
                        if (requestId == null) {
                            result.error("INVALID_ARGUMENTS", "Missing request ID", null)
                        } else {
                            val cancelled = AtomicBoolean(false)
                            cancellations[requestId] = cancelled
                            worker.execute {
                                try {
                                    val decoded = NativeImageMethods.decodeDownsampled(
                                        call.arguments,
                                    ) { cancelled.get() }
                                    mainHandler.post { result.success(decoded) }
                                } catch (error: CancellationException) {
                                    mainHandler.post {
                                        result.error("CANCELLED", "Image decode cancelled", null)
                                    }
                                } catch (error: IllegalArgumentException) {
                                    mainHandler.post {
                                        result.error("INVALID_ARGUMENTS", error.message, null)
                                    }
                                } catch (error: OutOfMemoryError) {
                                    mainHandler.post {
                                        result.error("OUT_OF_MEMORY", "Native image decode ran out of memory", null)
                                    }
                                } catch (error: Exception) {
                                    mainHandler.post {
                                        result.error("DECODE_FAILED", error.message, null)
                                    }
                                } finally {
                                    cancellations.remove(requestId, cancelled)
                                }
                            }
                        }
                    }
                    "cancelDecode" -> {
                        val requestId = (call.arguments as? Map<*, *>)?.get("requestId") as? Int
                        if (requestId == null) {
                            result.error("INVALID_ARGUMENTS", "Missing request ID", null)
                        } else {
                            cancellations[requestId]?.set(true)
                            result.success(null)
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
        cancellations.values.forEach { it.set(true) }
        worker.shutdownNow()
        super.onDestroy()
    }
}
