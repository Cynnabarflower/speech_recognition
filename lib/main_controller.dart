import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_archive/flutter_archive.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

import 'vosk_speech_recognizer.dart';

class MainController extends GetxController {
  var recording = false.obs;
  var recordingSeconds = 0.obs;
  String? lastOutline;
  final _recorder = FlutterSoundRecorder();
  var output = ''.obs;
  RxString model = ''.obs;
  String recPath = '';
  RxString modelPath = ''.obs;
  var modelProgress = 0.0.obs;
  var modelProgressMessage = ''.obs;
  var processing = false.obs;

  @override
  void onInit() async {
    await initRecorder();
    recPath = '${(await getApplicationDocumentsDirectory()).path}/rec.wav';
    super.onInit();
  }

  Future<void> initRecorder() async {
    final granted = (await Permission.microphone.request()).isGranted;
    if (granted) {
      await _recorder.openAudioSession(
          audioFlags: outputToSpeaker | allowBlueToothA2DP | allowAirPlay);
    }
  }

  void recordPressed() async {
    if (modelProgress.value != 1.0) {
      showModalBottomSheet(
          context: Get.context!,
          builder: (c) => Container(
                padding: EdgeInsets.all(8.0),
                child: Text('Model not found'),
              ));
      return;
    }
    if (_recorder.isRecording) {
      stopRecording();
    } else {
      startRecording();
    }
  }

  Future loadModel() async {
    try {
      modelProgress.trigger(0.1);
      modelProgressMessage.trigger('...');
      var uri = Uri.parse(
          "https://alphacephei.com/vosk/models/vosk-model-small-ru-0.22.zip");
      var cacheDir = (await getExternalCacheDirectories())!.first;
      var modelsDir = await Directory("${cacheDir.path}/vosk_models").create();
      var tmpDir = await getTemporaryDirectory();
      modelProgress.trigger(0.2);
      modelProgressMessage.trigger('Downloading...\n${uri}');
      var res = await (await HttpClient().getUrl(uri)).close();
      modelProgress.trigger(0.5);
      var zipFile = File("${tmpDir.path}/downloaded.zip");
      await res.pipe(zipFile.openWrite());
      modelProgressMessage.trigger('Extracting...');
      await ZipFile.extractToDirectory(
          zipFile: zipFile, destinationDir: modelsDir
      );
      modelProgress.trigger(0.8);
      modelProgressMessage.trigger('Initing...');
      var folderName = uri.pathSegments.last.replaceAll(".zip", "");
      modelPath.trigger(Directory("${modelsDir.path}/$folderName").path);
      var initResult = await androidPlatform
          .invokeMethod("initModel", {"path": modelPath.value});
      modelProgressMessage.value = '';
      modelProgress.trigger(1.0);
      if (initResult != null) {
        throw Exception(initResult.toString());
      }
    } catch (e) {
      modelProgress.trigger(0);
      showModalBottomSheet(
          context: Get.context!,
          builder: (c) => Container(
                padding: EdgeInsets.all(8.0),
                child: Text(e.toString()),
              ));
    }
  }

  void processFile() async {
    var f = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );
    try {
      if (f != null && f.files.isNotEmpty) {
        processing.trigger(true);
        var path = f.files.first.path!;
        if (!path.endsWith('wav')) {
          try {
            var outpath = '${(await getTemporaryDirectory()).path}/temp.wav';
            await flutterSoundHelper.convertFile(
                path, getCodec(path), outpath, Codec.pcm16);
            if (File(outpath).existsSync()) {
              path = outpath;
            } else {
              throw Exception('Cant convert');
            }
          } catch (e) {
            showModalBottomSheet(
                context: Get.context!,
                builder: (c) =>
                    Container(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(e.toString()),
                    ));
            return;
          }
        }
        var t = (await androidPlatform.invokeMethod(
            "transcribe", {"path": path})) ?? '';
        // if (t.isNotEmpty) {
        //   var t2 = (await checkSpelling(t));
        //   if (t2.isNotEmpty) {
        //     output.trigger(t2);
        //   }
        // }
        output.trigger(t);
      }
    } catch(_) {}
    processing.trigger(false);
  }

  Codec getCodec(String p) {
    if (p.endsWith('mp3')) {
      return Codec.mp3;
    }
    if (p.endsWith('m4a')) {
      return Codec.aacADTS;
    }
    if (p.endsWith('flac')) {
      return Codec.flac;
    }
    return Codec.defaultCodec;
  }

  Future stopRecording() async {
    await _recorder.stopRecorder();
    recording.trigger(false);
    processing.trigger(true);
    recordingSeconds.trigger(0);
    String t = (await androidPlatform.invokeMethod("transcribe", {"path": recPath})) ?? '';
    // if (t.isNotEmpty) {
    //   var t2 = (await checkSpelling(t)) ?? '';
    //   if (t2.isNotEmpty) {
    //     output.trigger(t2);
    //   }
    // }
    output.trigger(t);
    processing.trigger(false);
  }

  Future checkSpelling(text) async {
    var r  = await http.post(
      Uri.parse('http://api.text.ru/post'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'text': text,
        'userkey': '28f140940f24d3f6e872547d6c2b1196',
        'jsonvisible' : 'detail'
      }),
    );
    if (r.statusCode == 200) {
      var uid = jsonDecode(r.body)['text_uid'];
      var r2  = await http.post(
        Uri.parse('http://api.text.ru/post'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'uid': uid,
          'userkey': '28f140940f24d3f6e872547d6c2b1196'
        }),
      );
      if (r.statusCode == 200) {
        var t =  jsonDecode(r2.body)['spell_check'];
        return t;
      }
    }
  }

  Future startRecording() async {
    await _recorder.startRecorder(
        codec: Codec.pcm16WAV,
        toFile: '${(await getApplicationDocumentsDirectory()).path}/rec.wav',
        sampleRate: 44100,
        bitRate: 128000);
    recording.trigger(true);
    timer();
  }

  void timer() async {
    int t = 0;
    while (recording.isTrue) {
      recordingSeconds.trigger(t++);
      await Future.delayed(Duration(seconds: 1));
    }
  }
}
