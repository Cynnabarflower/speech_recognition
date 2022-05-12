import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:audio_streamer/audio_streamer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as mat;
import 'package:flutter/services.dart';
import 'package:flutter_archive/flutter_archive.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_sound/flutter_sound.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/transcoder/v1.dart';
import 'package:ml_linalg/linalg.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:speech_recognition/color_text_editing_controller.dart';
import 'package:speech_recognition/diarization.dart';
import 'package:speech_recognition/doc_helper.dart';
import 'package:speech_recognition/docs_controller.dart';
import 'package:speech_recognition/main.dart';
import 'package:googleapis/docs/v1.dart' as docs;
import 'package:async_zip/async_zip.dart' as azip;
import 'package:speech_recognition/user_model.dart';

import 'Isolate_utils.dart';

enum ModelVariant {
  small,
  big,
}

extension ModelVariantExtension on ModelVariant {
  bool get isSmall => this == ModelVariant.small;
  bool get isBig => this == ModelVariant.big;
}

class MainController extends GetxController {
  var recording = false.obs;
  StreamController<double> noiseController = StreamController();
  var recordingSeconds = 0.obs;
  String? lastOutline;
  final _recorder = FlutterSoundRecorder();
  var currentInput = ''.obs;
  String previousInput = '';
  RxString model = ''.obs;
  String recPath = '';
  RxString modelPath = ''.obs;
  Rx<ModelVariant?> currentModelVariant = Rx(null);
  var modelProgress = 0.0.obs;
  var modelProgressMessage = ''.obs;
  var processing = false.obs;
  var textColor = Colors.black;
  final StreamController<Food> _streamController = StreamController();
  GoogleSignIn googleSignIn = GoogleSignIn(
  scopes: <String>[
  'email',
  'https://www.googleapis.com/auth/documents',
  'https://www.googleapis.com/auth/drive'
  ],
  );
  final Rx<GoogleSignInAccount?> googleUser = Rx(null);
  bool isDownloading = false;
  final qcontroller = Rx(quill.QuillController.basic());
  GlobalKey editorKey = GlobalKey();
  RxBool ignoreFocus = false.obs;
  var minDist = 0.05.obs;

  final _loadedModels = Map.fromIterable(ModelVariant.values, value: (v) => false);

  final EventChannel eventChannel = EventChannel('eventChannel');
  IOSink? fileSink;

  RxList<FileSystemEntity> files = <FileSystemEntity>[].obs;

  RxMap<String, UserModel> users = <String, UserModel>{}.obs;
  int usersCount = 0;
  Map<String, List<List<double>>> usersSamples = <String, List<List<double>>>{};
  List<double> currentSample = [];
  List<double> recordingList = [];
  String? currentUser;
  ScrollController usersListController = ScrollController();

  AudioStreamer audioStreamer = AudioStreamer();

  IsolateUtils isolateUtils = IsolateUtils();

  @override
  void onInit() async {
    await isolateUtils.start();
    await initRecorder();
    _streamController.stream.listen((event) {
      if (event is FoodData) {
        fileSink!.add(event.data ?? []);
      } else if (event is FoodEvent) {
        // f.add(event ?? []);
      }
    });

    recPath = '${(await getApplicationDocumentsDirectory()).path}/rec.wav';

    updateModelsLoaded();

    super.onInit();
  }

  Future loadSpeakerModel({force = false}) async {
    var tmpDir = await getTemporaryDirectory();
    var cacheDir = (await getExternalCacheDirectories())!.first;
    var speakerDir = await Directory("${cacheDir.path}/vosk_models_speaker").create();
    if (force || speakerDir.listSync().isEmpty) {
      var uri = Uri.parse('https://alphacephei.com/vosk/models/vosk-model-spk-0.4.zip');
      modelProgressMessage.trigger('Downloading speaker\n${uri}');
      var zipFile = File("${tmpDir.path}/downloaded.zip");
      var response = await http.Client()
          .send(http.Request('GET', uri));
      var length = response.contentLength ?? 0;
      var received = 0;

      await zipFile.openWrite().addStream(
          response.stream.map((value) {
            received += value.length;
            modelProgressMessage.trigger(
                'Speaker ${(received / length * 100).toPrecision(1)}%');
            return value;
          })
      );
      await ZipFile.extractToDirectory(
          zipFile: zipFile, destinationDir: speakerDir,
          onExtracting: (zipEntry, progress) {
            modelProgressMessage.trigger('Extracting ${progress * 100}%');
            modelProgress.trigger(0.5 + 0.4 * progress);
            return ZipFileOperation.includeItem;
          }
      );
    }

    var result = await androidPlatform.invokeMethod("initSpeakerModel", {"path": speakerDir.listSync().first.path});

    modelProgress.trigger(1.0);
  }

  Future<void> initRecorder() async {
    final granted = (await Permission.microphone.request()).isGranted;
    if (granted) {
      await _recorder.openAudioSession(
          audioFlags: outputToSpeaker | allowBlueToothA2DP | allowAirPlay);
    }
  }

  void recordPressed() async {
    if (currentModelVariant.value == null) {
      await loadModel();
      // showModalBottomSheet(
      //     context: Get.context!,
      //     builder: (c) => Container(
      //           padding: const EdgeInsets.all(8.0),
      //           child: const Text('Loading model...'),
      //         ));
      return;
    }
    if (recording.isTrue) {
      // stopRecording();
      recording.trigger(false);
      androidPlatform.invokeMethod("stopListening");

      saveToFile(qcontroller.value.document.getPlainText(0, qcontroller.value.document.length), [...recordingList]);
      recordingList.clear();
      await audioStreamer.stop();
    } else {
      recordingList.clear();
      currentSample.clear();
      recording.trigger(true);
      androidPlatform.invokeMethod("listenMic");
      await audioStreamer.start(onAudioData, (){});
      timer();
      // startRecording();
    }
  }

  void onAudioData(List<double> data) {
    recordingList.addAll(data);
    currentSample.addAll(data);

    double max = data.fold(0.0, (double p, e) => e > p ? e : p);
    double maxAmp = pow(2, 15) + 0.0;
    noiseController.add(20 * log(maxAmp * max) * log10e);
  }

  Future saveToFile(text, List<double> rec) async {
    var now = DateTime.now();
    print('saving: $text');
    var path = (await getApplicationDocumentsDirectory()).path;
    var f = File('$path/recordings/${now.toString()}.txt')..createSync(recursive: true);
    f.writeAsString(text);
    await loadFiles();
  }

  Future loadFiles() async {
    var directory = (await getApplicationDocumentsDirectory()).path;
    files.assignAll(
        (Directory("$directory/recordings")..createSync()).listSync()
    );
    // var filenames = await firebaseProvider?.getFilenames() ?? [];
    // setState(() {
    //   uploadedFiles.assignAll(filenames);
    // });
  }

  Future signIn() async {
    if (await googleSignIn.isSignedIn()) {
      await googleSignIn.signOut();
    }
    googleUser.trigger(await googleSignIn.signIn());

    // if (googleUser.value != null && await googleSignIn.isSignedIn()) {
    //   var auth = await googleUser.value!.authentication;
    // }

  }

  Future<String?> downloadModel(Directory modelsDir, ModelVariant variant) async {
    Timer? timer;
    try {
      isDownloading = true;
      var tmpDir = await getTemporaryDirectory();
      Uri uri;
      if (variant.isSmall) {
        uri = Uri.parse(
            "https://alphacephei.com/vosk/models/vosk-model-small-ru-0.22.zip"
        );
      } else if (variant.isBig) {
        uri = Uri.parse(
            "https://alphacephei.com/vosk/models/vosk-model-ru-0.22.zip"
        );
      } else {
        return '';
      }
      modelProgress.trigger(0.1);
      modelProgressMessage.trigger('Downloading...\n${uri}');

      var zipFile = File("${tmpDir.path}/downloaded.zip");
      var response = await http.Client()
          .send(http.Request('GET', uri));
      var length = response.contentLength ?? 0;
      var received = 0;
      var startDownloadingTime = DateTime.now();

      timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        var estSeconds = ((DateTime.now().difference(startDownloadingTime).inSeconds / received) * (length - received)).floor();
        var estMinutes = estSeconds ~/ 60;
        estSeconds %= 60;
        modelProgressMessage.trigger('${(received/length*100).toPrecision(1)}% (${estMinutes.toString().padLeft(2, '0')}:${estSeconds.toString().padLeft(2, '0')})');
        modelProgress.trigger(0.1 + 0.4 * (received/length));
      });

      await zipFile.openWrite().addStream(
      response.stream.map((value) {
        received += value.length;
        return value;
      })
      );
      timer.cancel();
      // zipFile.writeAsBytesSync(t);

      modelProgress.trigger(0.5);
      modelProgressMessage.trigger('Extracting...');

      await ZipFile.extractToDirectory(
          zipFile: zipFile, destinationDir: modelsDir,
        onExtracting: (zipEntry, progress) {
          modelProgressMessage.trigger('Extracting ${progress * 100}%');
          modelProgress.trigger(0.5 + 0.4 * progress);
          return ZipFileOperation.includeItem;
        }
      );
      modelProgress.trigger(0.9);
      modelProgressMessage.trigger('Initing...');
      var folderName = uri.pathSegments.last.replaceAll(".zip", "");
      return Directory("${modelsDir.path}/$folderName").path;
    } catch (e) {
      e.printError();
    } finally {
      timer?.cancel();
      isDownloading = false;
    }
  }

  Future<String?> getModelPath(ModelVariant modelVariant) async {
    var cacheDir = (await getExternalCacheDirectories())!.first;
    var modelsDir = await Directory("${cacheDir.path}/vosk_models").create();
    var smallModel = modelsDir.listSync().where((element) => element.path.contains('small'));
    var bigModel = modelsDir.listSync().where((element) => !element.path.contains('small'));
    if (modelVariant.isSmall && smallModel.isNotEmpty) {
      return smallModel.first.path;
    } else if (modelVariant.isBig && bigModel.isNotEmpty) {
      return bigModel.first.path;
    }
  }

  bool isModelLoaded(ModelVariant modelVariant) {
    return _loadedModels[modelVariant]!;
  }

  Future updateModelsLoaded() async {
    _loadedModels.forEach((key, value) async {
      _loadedModels[key] = await getModelPath(key) != null;
    });
    currentModelVariant.refresh();
  }

  Future loadModel([ModelVariant modelVariant = ModelVariant.small]) async {
    try {
      currentModelVariant.value = null;
      modelProgress.trigger(0.1);
      modelProgressMessage.trigger('...');
      var cacheDir = (await getExternalCacheDirectories())!.first;
      var modelsDir = await Directory("${cacheDir.path}/vosk_models").create();
      var path = await getModelPath(modelVariant) ?? await downloadModel(modelsDir, modelVariant);
      if (path != null) {
        modelPath.trigger(path);
      } else {
        showModalBottomSheet(
            context: Get.context!,
            builder: (c) => Container(
              padding: EdgeInsets.all(8.0),
              child: Text('Не удалось загрузить модель'),
            ));
        return;
      }
      var initResult = await androidPlatform
          .invokeMethod("initModel", {"path": modelPath.value});
      modelProgressMessage.value = '';
      modelProgress.trigger(1.0);
      if (initResult != null) {
        throw Exception(initResult.toString());
      }
      currentModelVariant.trigger(modelVariant);
      updateModelsLoaded();
      await loadSpeakerModel();
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
        var start = max(qcontroller.value.document.length - 1, 0);
        qcontroller.value.document.insert(start,'\n' + t);
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

/*
  Future stopRecording() async {
    await _recorder.stopRecorder();
    recording.trigger(false);
    processing.trigger(true);
    recordingSeconds.trigger(0);
    String t = (await androidPlatform.invokeMethod("transcribe", {"path": recPath})) ?? '';
    output.trigger(t);
    print('Done: $t');
    processing.trigger(false);
  }

  Future checkSpelling(text) async {

     var r  = await http.post(
       Uri.parse('https://api.text.ru/post'),
      */
/* headers: <String, String>{
         'Content-Type': 'application/json; charset=UTF-8',
       },*//*

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

  Future startRecording({suffix = ''}) async {
    fileSink = File('${(await getApplicationDocumentsDirectory()).path}/rec$suffix.wav').openWrite();
    await _recorder.startRecorder(
        // codec: Codec.pcm16WAV,
        codec: Codec.pcm16,
        // toFile: '${(await getApplicationDocumentsDirectory()).path}/rec$suffix.wav',
        toStream: _streamController.sink,
        sampleRate: 44100,
        bitRate: 128000);
    recording.trigger(true);
    timer();
    // await Future.delayed(Duration(seconds: 1));
    // await androidPlatform.invokeMethod("listenMic");

    //
  }
*/

  static const downscaleFactor = 4;
  static final targetSampleRate = AudioStreamer.sampleRate.toDouble()/downscaleFactor;
  static final windowSize = IsolateUtils.getWindowSize(targetSampleRate);

  void timer() async {
    int t = 0;
    int counter = 0;
    print('timer!');
    while (recording.isTrue) {
      if (counter++ % 10 == 0) {
        recordingSeconds.trigger(t++);
      }
      Map? d = await androidPlatform.invokeMethod("getData");
      print(d);
      if (d != null && (d['data'] as List).isNotEmpty && d['data'].last.trim().isNotEmpty) {
        if (currentInput.isEmpty && !d.containsKey('final')) {
          currentSample.clear();
        }
        currentInput.trigger(d['data'].last.toString().trim());
      }
      if (d != null && (d['final'] as String).trim().isNotEmpty && currentSample.isNotEmpty) {
        var sample = [...currentSample];
        currentSample.clear();
        String selectionUser = '';
        if (d.containsKey('spk') && d['spk'] != null) {
          (Map d) async {
            if (currentInput.isEmpty) return;
            currentInput.trigger('');
            var features = await inference(IsolateData(
                sample, targetSampleRate, windowSize, downscaleFactor
            ));
            print('Got features: $features');
            var notZero = features.any((element) => element != 0);
            if (notZero) {
              var spk = ((d['spk']) as List<Object?>).map((e) => e as double).toList();
              if (currentUser == null) {
                selectionUser = getUser(spk, features);
              } else {
                selectionUser = getUser(spk, features, user: currentUser);
              }
              insertUserText(users[selectionUser]!, d['final'].trim());
            }
          }(d);
        }
      }
      await Future.delayed(Duration(milliseconds: 100));
    }
  }

  void insertUserText(UserModel selectionUser, String userText) {

    var textColor = selectionUser.color;

    TextSelection selection = qcontroller.value.selection;
    var text =  '\n${selectionUser.name}: $userText';
    var start = max(qcontroller.value.document.length - 1, 0);
    qcontroller.value.document.insert(start, text);
    qcontroller.value.formatTextStyle(start, text.length, quill.Style.attr({
      'color' : quill.ColorAttribute('#${textColor.red.toRadixString(16).padLeft(2,'0')}${textColor.green.toRadixString(16).padLeft(2,'0')}${textColor.blue.toRadixString(16).padLeft(2,'0')}')
    }));
    qcontroller.value.formatTextStyle(start + 1, selectionUser.name.length, quill.Style.attr({
      'bold' : quill.BoldAttribute()
    }));
    qcontroller.value.updateSelection(selection, quill.ChangeSource.REMOTE);
    if (ignoreFocus.isTrue) {
      qcontroller.value.ignoreFocusOnTextChange = true;
    }
    qcontroller.value.notifyListeners();
    if (ignoreFocus.isTrue) {
      qcontroller.refresh();
    }
  }

  String addUser({String? name}) {
    name ??= 'User${++usersCount}';
    users[name] = UserModel(name, null, []);
    return name;
  }

  String getUser(List<double> spk, List<double> features, {isNew = false, String? user}) {

    var vector = Vector.fromList(spk).normalize();
    var vector2 = Vector.fromList(features).normalize();
    double minDist = 2.0;
    print('getUser: $isNew $features $user');
    if (user != null) {
      users[user]!.vectors.addAll(
          [
            if (vector.isNotEmpty) vector,
            if (vector2.isNotEmpty) vector2,
          ]
      );
      return user;
    } else if (!isNew && users.isNotEmpty) {
      for (var entry in users.entries) {
        for (var v in entry.value.vectors) {
          /*if (v.length == vector.length) {
            var dist = vector.distanceTo(v, distance: Distance.cosine);
            if (dist > 0 && dist < minDist) {
              minDist = dist;
              user = entry.key;
            }
          } else*/ if (v.length == vector2.length) {
            var dist = vector2.distanceTo(v, distance: Distance.cosine);
            if (dist > 0 && dist < minDist) {
              minDist = dist;
              user = entry.key;
            }
          }
        }
      }
      print('MIN DIST: $minDist with $user');
      if (minDist < this.minDist.value && minDist > 0.0) {
        return user!;
      }
    }
    var newUser = addUser();
    users[newUser]!.vectors = [
      if (vector.isNotEmpty) vector,
      if (vector2.isNotEmpty) vector2,
    ];
    return newUser;
  }

  void changeUser(UserModel oldUser, UserModel newUser) async {

  }

  Future<void> addToDrive() async {
    String plainText = qcontroller.value.document.toPlainText();
    docs.Document document = docs.Document();
    document.addText(plainText, TextStyle(fontWeight: FontWeight.bold));
    document.title = plainText.substring(0, max(plainText.length, 20));
    var doc = await Get.find<DocsController>().saveDoc(document, text: qcontroller.value.document.toPlainText());
    print('Saved: ${doc}');
  }

  /// Runs inference in another isolate
  Future<List<double>> inference(IsolateData isolateData) async {
    ReceivePort responsePort = ReceivePort();
    isolateUtils.sendPort
        .send(isolateData..responsePort = responsePort.sendPort);
    var results = await responsePort.first;
    return results;
  }

}
