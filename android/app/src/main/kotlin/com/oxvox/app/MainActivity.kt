package com.oxvox.app

import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.speech.RecognitionSupport
import android.speech.RecognitionSupportCallback
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// "oxvox/speech_langs": which speech languages the phone's recognizer has
/// (Android 13+), and asks it to download one for offline use.
class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Edge-to-edge on all Android versions, matching Android 15+ (targetSdk 35).
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "oxvox/speech_langs")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "support" -> support(call.argument<String>("lang") ?: "en-GB", result)
                    "download" -> download(call.argument<String>("lang") ?: "en-GB", result)
                    "inCall" -> {
                        // No permission needed: the audio mode shows ringing, phone
                        // calls, and internet calls (WhatsApp, Messenger, Meet).
                        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        result.success(
                            am.mode == AudioManager.MODE_RINGTONE ||
                                am.mode == AudioManager.MODE_IN_CALL ||
                                am.mode == AudioManager.MODE_IN_COMMUNICATION
                        )
                    }
                    "installTts" -> {
                        try {
                            startActivity(
                                Intent(TextToSpeech.Engine.ACTION_INSTALL_TTS_DATA)
                                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            )
                            result.success(true)
                        } catch (e: Exception) {
                            try {
                                startActivity(Intent("com.android.settings.TTS_SETTINGS"))
                                result.success(true)
                            } catch (e2: Exception) {
                                result.success(false)
                            }
                        }
                    }
                    "openSettings" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_VOICE_INPUT_SETTINGS))
                            result.success(true)
                        } catch (e: Exception) {
                            try {
                                startActivity(Intent(Settings.ACTION_LOCALE_SETTINGS))
                                result.success(true)
                            } catch (e2: Exception) {
                                result.success(false)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun langIntent(lang: String) =
        Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, lang)
        }

    /// Returns {installed, pending, supported, online} lists of language tags,
    /// or null when the phone cannot tell (Android 12 and older, or no recognizer).
    private fun support(lang: String, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            !SpeechRecognizer.isRecognitionAvailable(this)
        ) {
            result.success(null)
            return
        }
        val recognizer = SpeechRecognizer.createSpeechRecognizer(this)
        var answered = false
        fun reply(value: Any?) {
            if (answered) return
            answered = true
            runOnUiThread {
                result.success(value)
                recognizer.destroy()
            }
        }
        try {
            recognizer.checkRecognitionSupport(
                langIntent(lang),
                mainExecutor,
                object : RecognitionSupportCallback {
                    override fun onSupportResult(s: RecognitionSupport) {
                        reply(
                            mapOf(
                                "installed" to s.installedOnDeviceLanguages,
                                "pending" to s.pendingOnDeviceLanguages,
                                "supported" to s.supportedOnDeviceLanguages,
                                "online" to s.onlineLanguages,
                            )
                        )
                    }

                    override fun onError(error: Int) = reply(null)
                },
            )
        } catch (e: Exception) {
            reply(null)
        }
    }

    /// Asks the recognizer to download [lang] (it shows its own prompt/progress).
    private fun download(lang: String, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(false)
            return
        }
        val recognizer = SpeechRecognizer.createSpeechRecognizer(this)
        try {
            recognizer.triggerModelDownload(langIntent(lang))
            result.success(true)
        } catch (e: Exception) {
            result.success(false)
        } finally {
            recognizer.destroy()
        }
    }
}
