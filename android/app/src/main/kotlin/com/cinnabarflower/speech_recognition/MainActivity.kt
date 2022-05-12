package com.cinnabarflower.speech_recognition

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import org.vosk.Recognizer
import org.vosk.Model
import org.vosk.SpeakerModel
import org.vosk.android.RecognitionListener
import org.vosk.android.SpeechService
import org.vosk.android.SpeechStreamService
import java.io.File
import java.io.FileInputStream
import java.io.InputStream

class VOListener(val onRes: (String?) -> Unit, val onFinalRes: (String?) -> Unit) :
        RecognitionListener {
    public override fun onTimeout() {
    }

    public override fun onError(exception: java.lang.Exception?) {
        onFinalResult(null)
    }

    public override fun onFinalResult(hypothesis: String?) {
        if (hypothesis != null) {
            System.out.println(hypothesis);
            val text = JSONObject(hypothesis).getString("text").toString()
            onFinalRes(text)
        } else onFinalRes(null)
    }

    public override fun onPartialResult(hypothesis: String?) {
    }

    public override fun onResult(hypothesis: String?) {
        if (hypothesis != null) {
            System.out.println(hypothesis);
            val text = JSONObject(hypothesis).getString("text").toString()
            onRes(text)
        } else onRes(null)
    }
}

class MainActivity : FlutterActivity() {
    private var model: Model? = null;
    private var punctuationModel: Model? = null;
    private var speakerModel: SpeakerModel? = null;
    private var speechService : SpeechService? = null;
    private var data : ArrayList<String> = ArrayList<String>();
    private var finalData : String = "";
    private var finalSpk : ArrayList<Double>? = null;

    private fun initSpeakerModel(call: MethodCall, result: MethodChannel.Result) {
        try {
            val path = call.argument<String>("path")
            if (path == null) {
                result.error("Null path provided", "Cannot transcribe null path", null)
                return
            }
            this.speakerModel = SpeakerModel(path)

            result.success(null);

        } catch (e: Exception) {
            result.error("Couldn't initialize model", e.toString(), null);
        }
    }

    private fun initPunctuationModel(call: MethodCall, result: MethodChannel.Result) {
        try {
            val path = call.argument<String>("path")
            if (path == null) {
                result.error("Null path provided", "Cannot transcribe null path", null)
                return
            }
            this.punctuationModel = Model(path)

            result.success(null);

        } catch (e: Exception) {
            result.error("Couldn't initialize model", e.toString(), null);
        }
    }

    private fun initModel(call: MethodCall, result: MethodChannel.Result) {
        try {
            val path = call.argument<String>("path")
            if (path == null) {
                result.error("Null path provided", "Cannot transcribe null path", null)
                return
            }
            this.model = Model(path)

            result.success(null);

        } catch (e: Exception) {
            result.error("Couldn't initialize model", e.toString(), null);
        }
    }

    private fun getData(call: MethodCall, result: MethodChannel.Result) {
        result.success(mapOf("data" to data, "final" to finalData, "spk" to finalSpk));
//        if (clear) {
        finalData = "";
            data.clear();
        finalSpk = null;
//        }
    }

    private fun listenMic(call: MethodCall, result: MethodChannel.Result) {
        try {
            if (this.model == null) {
                result.error("Model uninitialized", null, null)
                return
            }
//            val results = arrayListOf<String>()
            try {
                val rec = Recognizer(this.model, 16000.0f, this.speakerModel)
                speechService = SpeechService(rec, 16000.0f)
                speechService!!.startListening(object : RecognitionListener{
                    override
                    fun onPartialResult(hypothesis: String?) {
                        if (hypothesis != null) {
                            val jsonObject = JSONObject(hypothesis);
//                            System.out.println("onPartialResult: " + hypothesis);
                            if (jsonObject.has("partial")) {
                                val text = jsonObject.getString("partial").toString()
//                                results.add(text);
                                data.add(text);
//                                System.out.println(text);
                            } else {
//                                System.out.println(jsonObject.toString())
                            }
                        } else {
//                            System.out.println("rec null");
                        }
                    }

                    override
                    fun onResult(hypothesis: String?) {
                        val jsonObject = JSONObject(hypothesis);
//                        System.out.println("onResult: " + hypothesis);
                        if (jsonObject.has("text")) {
                            val text = jsonObject.getString("text").toString()
                            finalData = text;
                            if (jsonObject.has("spk")) {
                                val spk = jsonObject.getJSONArray("spk");
                                finalSpk = Array(spk.length()) {
                                    spk.getDouble(it)
                                }.toCollection(ArrayList())
                            } else {
                                finalSpk = null;
                            }
                        } else {
//                            System.out.println(jsonObject.toString())
                        }
                    }

                    override
                    fun onFinalResult(hypothesis: String?) {
                    }

                    override
                    fun onError(exception: Exception?) {
                    }

                    override
                    fun onTimeout() {
                    }
                })
            } catch (e: Exception) {
                result.error("Couldn't transcribe", e.toString(), null)
            }
        } catch (e: Exception) {
            result.error("Couldn't transcribe", e.toString(), null)
        }
    }

    private fun stopListening(call: MethodCall, result: MethodChannel.Result) {
        speechService?.stop()
        speechService = null;
        System.out.print("Service stopped")
    }

    private fun transcribe(call: MethodCall, result: MethodChannel.Result) {
            val path = call.argument<String>("path")
            if (this.model == null) {
                result.error("Model uninitialized", null, null)
                return
            }
            val file = File(path)
            val inputStream = FileInputStream(file)
        _transcribe(inputStream, result);
    }

    private fun _transcribe(inputStream : InputStream, result: MethodChannel.Result) {
        try {
            val recognizer = Recognizer(this.model, 44100F, this.speakerModel);
            val speechStreamService = SpeechStreamService(recognizer, inputStream, 44100F)
            val results = arrayListOf<String>()
            speechStreamService.start(VOListener({ res ->
                if (res != null) {
                    results.add(res)
                }
            }, { res ->
                if (res != null) {
                    results.add(res)
                }
                if (results.isEmpty() || results.joinToString("").isBlank()) {
                    result.success(null)
                } else {
                    result.success(results.joinToString("\n"))
                }
                speechStreamService.stop()
            }))
    } catch (e: Exception) {
        result.error("Couldn't transcribe", e.toString(), null)
    }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "channel"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "transcribe" -> transcribe(call, result)
                "initModel" -> initModel(call, result)
                "initSpeakerModel" -> initSpeakerModel(call, result)
                "getData" -> getData(call, result)
                "listenMic" -> listenMic(call, result)
                "stopListening" -> stopListening(call, result)
                else -> result.notImplemented()
            }
        }
    }


}
