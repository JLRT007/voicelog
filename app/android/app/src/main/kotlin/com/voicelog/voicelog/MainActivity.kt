package com.voicelog.voicelog

import android.Manifest
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val ERROR_SERVER_DISCONNECTED = 11
    }

    private var speechRecognizer: SpeechRecognizer? = null
    private var usingXiaomiFallback = false
    private var pendingRetryWithXiaomi = false
    private var retriedAfterBusy = false
    private val mainHandler = Handler(Looper.getMainLooper())
    private lateinit var speechChannel: MethodChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        speechChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.voicelog.voicelog/speech",
        )
        speechChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> result.success(isSpeechRecognitionAvailable())
                "startListening" -> startListening(result)
                "stopListening" -> {
                    speechRecognizer?.stopListening()
                    mainHandler.postDelayed({ releaseRecognizer() }, 600)
                    result.success(null)
                }
                "cancelListening" -> {
                    releaseRecognizer()
                    result.success(null)
                }
                "openSpeechServiceSettings" -> {
                    openSpeechServiceSettings()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isSpeechRecognitionAvailable(): Boolean {
        return SpeechRecognizer.isRecognitionAvailable(this) || recognitionServices().isNotEmpty()
    }

    private fun startListening(result: MethodChannel.Result) {
        if (!isSpeechRecognitionAvailable()) {
            result.error("unavailable", "没有检测到可用的语音识别服务", null)
            return
        }
        if (xiaomiAsrNeedsMicrophonePermission()) {
            result.error(
                "service_permission_denied",
                "小爱语音引擎没有麦克风权限。请在系统设置中打开“小爱语音引擎”的麦克风权限后重试。",
                null,
            )
            return
        }

        try {
            releaseRecognizer()
            retriedAfterBusy = false
            createRecognizer(useXiaomiFallback = false)
            pendingRetryWithXiaomi = hasXiaomiAsrService()
            speechRecognizer?.startListening(recognizerIntent())
            result.success(null)
        } catch (error: Throwable) {
            if (hasXiaomiAsrService()) {
                try {
                    createRecognizer(useXiaomiFallback = true)
                    pendingRetryWithXiaomi = false
                    speechRecognizer?.startListening(recognizerIntent())
                    result.success(null)
                    return
                } catch (fallbackError: Throwable) {
                    result.error(
                        "start_failed",
                        "系统默认和小米语音识别服务都启动失败：${fallbackError.localizedMessage}",
                        null,
                    )
                    return
                }
            }
            result.error("start_failed", error.localizedMessage ?: "语音识别启动失败", null)
        }
    }

    private fun createRecognizer(useXiaomiFallback: Boolean) {
        releaseRecognizer()
        usingXiaomiFallback = useXiaomiFallback
        speechRecognizer = if (useXiaomiFallback) {
            SpeechRecognizer.createSpeechRecognizer(
                this,
                ComponentName(
                    "com.xiaomi.mibrain.speech",
                    "com.xiaomi.mibrain.speech.asr.AsrService",
                ),
            )
        } else {
            SpeechRecognizer.createSpeechRecognizer(this)
        }
        speechRecognizer?.setRecognitionListener(voiceRecognitionListener())
    }

    private fun recognizerIntent(): Intent {
        return Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
            )
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "zh-CN")
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, "zh-CN")
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, packageName)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        }
    }

    private fun voiceRecognitionListener(): RecognitionListener {
        return object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                sendStatus("listening")
            }

            override fun onBeginningOfSpeech() {
                sendStatus("listening")
            }

            override fun onRmsChanged(rmsdB: Float) = Unit

            override fun onBufferReceived(buffer: ByteArray?) = Unit

            override fun onEndOfSpeech() {
                sendStatus("processing")
            }

            override fun onError(error: Int) {
                if (error == SpeechRecognizer.ERROR_RECOGNIZER_BUSY && !retriedAfterBusy) {
                    retriedAfterBusy = true
                    retryAfterBusy()
                    return
                }
                if (!usingXiaomiFallback && pendingRetryWithXiaomi && hasXiaomiAsrService()) {
                    pendingRetryWithXiaomi = false
                    try {
                        createRecognizer(useXiaomiFallback = true)
                        speechRecognizer?.startListening(recognizerIntent())
                        return
                    } catch (fallbackError: Throwable) {
                        sendError(
                            "xiaomi_fallback_failed",
                            fallbackError.localizedMessage ?: "小米语音识别服务启动失败",
                            permanent = true,
                        )
                        return
                    }
                }

                val code = errorCodeName(error)
                releaseRecognizer()
                sendError(code, errorMessage(error), permanent = isPermanentError(error))
            }

            override fun onResults(results: Bundle?) {
                sendResult(firstRecognitionText(results), isFinal = true)
                sendStatus("done")
                mainHandler.postDelayed({ releaseRecognizer() }, 300)
            }

            override fun onPartialResults(partialResults: Bundle?) {
                sendResult(firstRecognitionText(partialResults), isFinal = false)
            }

            override fun onEvent(eventType: Int, params: Bundle?) = Unit
        }
    }

    private fun retryAfterBusy() {
        sendStatus("processing")
        val shouldUseXiaomiFallback = usingXiaomiFallback
        releaseRecognizer()
        mainHandler.postDelayed({
            try {
                createRecognizer(useXiaomiFallback = shouldUseXiaomiFallback)
                speechRecognizer?.startListening(recognizerIntent())
            } catch (error: Throwable) {
                releaseRecognizer()
                sendError(
                    "ERROR_RECOGNIZER_BUSY",
                    "系统识别服务仍被占用，请稍等几秒后再试",
                    permanent = false,
                )
            }
        }, 900)
    }

    private fun firstRecognitionText(results: Bundle?): String {
        return results
            ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            ?.firstOrNull()
            .orEmpty()
    }

    private fun sendStatus(status: String) {
        runOnUiThread {
            speechChannel.invokeMethod("onSpeechStatus", mapOf("status" to status))
        }
    }

    private fun sendResult(text: String, isFinal: Boolean) {
        if (text.isBlank()) return
        runOnUiThread {
            speechChannel.invokeMethod(
                "onSpeechResult",
                mapOf("text" to text, "isFinal" to isFinal),
            )
        }
    }

    private fun sendError(code: String, message: String, permanent: Boolean) {
        runOnUiThread {
            speechChannel.invokeMethod(
                "onSpeechError",
                mapOf("code" to code, "message" to message, "permanent" to permanent),
            )
        }
    }

    private fun recognitionServices(): List<ResolveInfo> {
        val intent = Intent("android.speech.RecognitionService")
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.queryIntentServices(
                intent,
                PackageManager.ResolveInfoFlags.of(0),
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.queryIntentServices(intent, 0)
        }
    }

    private fun hasXiaomiAsrService(): Boolean {
        return recognitionServices().any { info ->
            info.serviceInfo?.packageName == "com.xiaomi.mibrain.speech" &&
                info.serviceInfo?.name == "com.xiaomi.mibrain.speech.asr.AsrService"
        }
    }

    private fun xiaomiAsrNeedsMicrophonePermission(): Boolean {
        if (!hasXiaomiAsrService()) return false
        return packageManager.checkPermission(
            Manifest.permission.RECORD_AUDIO,
            "com.xiaomi.mibrain.speech",
        ) != PackageManager.PERMISSION_GRANTED
    }

    private fun openSpeechServiceSettings() {
        val intent = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.parse("package:com.xiaomi.mibrain.speech"),
        ).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

    private fun releaseRecognizer() {
        speechRecognizer?.cancel()
        speechRecognizer?.destroy()
        speechRecognizer = null
    }

    private fun errorCodeName(error: Int): String {
        return when (error) {
            SpeechRecognizer.ERROR_AUDIO -> "ERROR_AUDIO"
            SpeechRecognizer.ERROR_CLIENT -> "ERROR_CLIENT"
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "ERROR_INSUFFICIENT_PERMISSIONS"
            SpeechRecognizer.ERROR_NETWORK -> "ERROR_NETWORK"
            SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "ERROR_NETWORK_TIMEOUT"
            SpeechRecognizer.ERROR_NO_MATCH -> "ERROR_NO_MATCH"
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "ERROR_RECOGNIZER_BUSY"
            SpeechRecognizer.ERROR_SERVER -> "ERROR_SERVER"
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "ERROR_SPEECH_TIMEOUT"
            ERROR_SERVER_DISCONNECTED -> "ERROR_SERVER_DISCONNECTED"
            else -> "ERROR_$error"
        }
    }

    private fun errorMessage(error: Int): String {
        return when (error) {
            SpeechRecognizer.ERROR_AUDIO -> "录音设备异常"
            SpeechRecognizer.ERROR_CLIENT -> "系统识别客户端异常"
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS ->
                if (xiaomiAsrNeedsMicrophonePermission()) {
                    "小爱语音引擎没有麦克风权限"
                } else {
                    "麦克风权限不足"
                }
            SpeechRecognizer.ERROR_NETWORK -> "网络错误"
            SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "网络超时"
            SpeechRecognizer.ERROR_NO_MATCH -> "没有识别到有效语音"
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "系统识别服务正忙"
            SpeechRecognizer.ERROR_SERVER -> "识别服务端异常"
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "没有检测到说话声音"
            ERROR_SERVER_DISCONNECTED -> "识别服务已断开"
            else -> "语音识别错误 $error"
        }
    }

    private fun isPermanentError(error: Int): Boolean {
        return when (error) {
            SpeechRecognizer.ERROR_CLIENT,
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS,
            SpeechRecognizer.ERROR_SERVER,
            -> true
            else -> false
        }
    }

    override fun onDestroy() {
        releaseRecognizer()
        super.onDestroy()
    }
}
