import 'dart:isolate';
import 'dart:math';

import 'diarization.dart';

/// Manages separate Isolate instance for inference
class IsolateUtils {
  static const String DEBUG_NAME = "InferenceIsolate";

  late Isolate _isolate;
  final ReceivePort _receivePort = ReceivePort();
  late SendPort _sendPort;

  SendPort get sendPort => _sendPort;

  Future<void> start() async {
    _isolate = await Isolate.spawn<SendPort>(
      entryPoint,
      _receivePort.sendPort,
      debugName: DEBUG_NAME,
    );

    _sendPort = await _receivePort.first;
  }

  static void entryPoint(SendPort sendPort) async {
    final port = ReceivePort();
    sendPort.send(port.sendPort);
    int poles = 30;
    // Diarization diarization = Diarization(8192, poles);
    Diarization diarization = Diarization(32768, poles);
    await for (IsolateData? isolateData in port) {
      if (isolateData != null) {
        if (isolateData.windowSize != diarization.windowSize) {
          diarization = Diarization(isolateData.windowSize, poles);
        }
        try {
          //44100
          // var data = diarization.extractFeatures(downscaleData(isolateData.data, isolateData.downscaleFactor), isolateData.targetSampleRate);
          var data = diarization.extractFeatures(isolateData.data, 44100);
          isolateData.responsePort?.send(data);
        } catch (e) {
          print('ISOLATE EXCEPTION');
          print(e);
        }
      }
    }
  }

  static List<double> downscaleData(List<double> data, int downScaleKoeff) {
    if (downScaleKoeff == 1) {
      return data;
    }
    var result = <double>[];
    int i = 0;
    for (var s in data) {
      if (i++ % downScaleKoeff == 0) {
        result.add(s);
      }
    }
    return result;
  }

  static int getWindowSize(double targetSampleRate) {
    var _pow = 13;
    int windowSize = pow(2, _pow).toInt();
    int prev = windowSize;
    while (true) {
      if ((targetSampleRate - windowSize).abs() >= (targetSampleRate - prev).abs()) {
        windowSize = prev;
        break;
      } else if (targetSampleRate > windowSize) {
        windowSize = pow(2, ++_pow).toInt();
      } else {
        windowSize = pow(2, --_pow).toInt();
      }
    }
    return windowSize;
  }

}

/// Bundles data to pass between Isolate
class IsolateData {
  SendPort? responsePort;
  List<double> data;
  int windowSize;
  int downscaleFactor;
  double targetSampleRate;
  IsolateData(this.data, this.targetSampleRate, this.windowSize, this.downscaleFactor);
}
