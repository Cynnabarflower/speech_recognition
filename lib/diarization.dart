import 'dart:math';

class Diarization {
  List<double> factors = [];
  int windowSize = 0;
  List<double> fadeInFactors = <double>[];
  List<double> fadeOutFactors = <double>[];
  int poles = 50;

  Diarization(this.windowSize, this.poles) {
    factors = List.filled(windowSize, 0);
    for (int i = 0; i < windowSize; i++) {
      factors[i] = 0.54 - (0.46 * cos((2 * pi * i) / (windowSize - 1)));
    }
  }

  List<double> removeSilence(List<double> voiceSample, double sampleRate) {
    int oneMilliInSamples = (sampleRate / 1000).round();

    int length = voiceSample.length;
    int minSilenceLength = 4 * oneMilliInSamples;
    int minActivityLength = 4 * oneMilliInSamples;
    List<bool> result = List.filled(length, false);

    if (length < minActivityLength) {
      return voiceSample;
    }

    int windowSize = oneMilliInSamples;
    List<double> correllation = List.filled(windowSize, 0);

    for (int position = 0;
        position + windowSize < length;
        position += windowSize) {
      List<double> window =
          voiceSample.sublist(position, position + windowSize);
      double mean = bruteForceAutocorrelation(window, correllation);
      result.fillRange(position, position + windowSize, mean > 0.0001);
    }

    mergeSmallSilentAreas(result, minSilenceLength);

    int silenceCounter = mergeSmallActiveAreas(result, minActivityLength);

    if (silenceCounter > 0) {
      int fadeLength = 2 * oneMilliInSamples;
      initFadeFactors(fadeLength);
      List<double> shortenedVoiceSample =
          List.filled(voiceSample.length - silenceCounter, 0, growable: true);
      int copyCounter = 0;
      for (int i = 0; i < result.length; i++) {
        if (result[i]) {
          // detect lenght of active frame
          int startIndex = i;
          int counter = 0;
          while (i < result.length && result[i++]) {
            counter++;
          }
          int endIndex = startIndex + counter;

          applyFadeInFadeOut(voiceSample, fadeLength, startIndex, endIndex);
          shortenedVoiceSample.replaceRange(copyCounter, copyCounter + counter,
              voiceSample.sublist(startIndex, startIndex + counter));
          copyCounter += counter;
        }
      }
      return shortenedVoiceSample;
    } else {
      return voiceSample;
    }
  }

  void applyFadeInFadeOut(
      List<double> voiceSample, int fadeLength, int startIndex, int endIndex) {
    int fadeOutStart = endIndex - fadeLength;
    for (int j = 0; j < fadeLength; j++) {
      voiceSample[startIndex + j] *= fadeInFactors[j];
      voiceSample[fadeOutStart + j] *= fadeOutFactors[j];
    }
  }

  void initFadeFactors(int fadeLength) {
    fadeInFactors = <double>[];
    fadeOutFactors = <double>[];
    for (int i = 0; i < fadeLength; i++) {
      fadeInFactors.add((1.0 / fadeLength) * i);
    }
    for (int i = 0; i < fadeLength; i++) {
      fadeOutFactors.add(1.0 - fadeInFactors[i]);
    }
  }

  double bruteForceAutocorrelation(
      List<double> voiceSample, List<double> correllation) {
    correllation.fillRange(0, correllation.length, 0);
    int n = voiceSample.length;
    for (int j = 0; j < n; j++) {
      for (int i = 0; i < n; i++) {
        correllation[j] += voiceSample[i] * voiceSample[(n + i - j) % n];
      }
    }
    double mean = 0.0;
    for (int i = 0; i < voiceSample.length; i++) {
      mean += correllation[i];
    }
    return mean / correllation.length;
  }

  void mergeSmallSilentAreas(List<bool> result, int minSilenceLength) {
    bool active;
    int increment = 0;
    for (int i = 0; i < result.length; i += increment) {
      active = result[i];
      increment = 1;
      while (
          (i + increment < result.length) && result[i + increment] == active) {
        increment++;
      }
      if (!active && increment < minSilenceLength) {
        result.fillRange(i, i + increment, !active);
      }
    }
  }

  int mergeSmallActiveAreas(List<bool> result, int minActivityLength) {
    bool active;
    int increment = 0;
    int silenceCounter = 0;
    for (int i = 0; i < result.length; i += increment) {
      active = result[i];
      increment = 1;
      while (
          (i + increment < result.length) && result[i + increment] == active) {
        increment++;
      }
      if (active && increment < minActivityLength) {
        result.fillRange(i, i + increment, !active);
        silenceCounter += increment;
      }
      if (!active) {
        silenceCounter += increment;
      }
    }
    return silenceCounter;
  }

  List<double> extractFeatures(List<double> voiceSample, double sampleRate) {
    List<double> voiceFeatures = List.filled(poles, 0.0);

    int counter = 0;
    int halfWindowLength = windowSize >> 2;

    voiceSample = removeSilence(voiceSample, sampleRate);

    for (int i = 0;
        (i + windowSize) < voiceSample.length;
        i += halfWindowLength) {
      var audioWindow = voiceSample.sublist(i, i + windowSize);
      applyHammingFunction(audioWindow);
      var lpcCoeffs = applyLinearPredictiveCoding(audioWindow, poles)[0];

      for (int j = 0; j < poles; j++) {
        voiceFeatures[j] += lpcCoeffs[j];
      }
      counter++;
    }

    if (counter > 1) {
      for (int i = 0; i < poles; i++) {
        voiceFeatures[i] /= counter;
      }
    }
    return voiceFeatures;
  }

  List<double> applyHammingFunction(List<double> data) {
    for (int i = 0; i < data.length; i++) {
      data[i] *= factors[i];
    }
    return data;
  }

  List<List<double>> applyLinearPredictiveCoding(
      List<double> window, int poles) {
    List<double> k = List.filled(poles, 0.0);
    List<double> output = List.filled(poles, 0.0);
    List<double> error = List.filled(poles, 0.0);
    List<List<double>> matrix = [];
    for (int i = 0; i < poles; i++) {
      matrix.add(List.filled(poles, 0.0));
    }

    List<double> autocorrelations = List.filled(poles, 0);
    for (int i = 0; i < poles; i++) {
      autocorrelations[i] = autocorrelate(window, i);
    }

    error[0] = autocorrelations[0];

    for (int m = 1; m < poles; m++) {
      double tmp = autocorrelations[m];
      for (int i = 1; i < m; i++) {
        tmp -= matrix[m - 1][i] * autocorrelations[m - i];
      }
      k[m] = tmp / error[m - 1];

      for (int i = 0; i < m; i++) {
        matrix[m][i] = matrix[m - 1][i] - k[m] * matrix[m - 1][m - i];
      }
      matrix[m][m] = k[m];
      error[m] = (1 - (k[m] * k[m])) * error[m - 1];
    }

    for (int i = 0; i < poles; i++) {
      if ((matrix[poles - 1][i]).isNaN) {
        output[i] = 0.0;
      } else {
        output[i] = matrix[poles - 1][i];
      }
    }

    return [output, error];
  }

  double autocorrelate(List<double> buffer, int lag) {
    if (lag > -1 && lag < buffer.length) {
      double result = 0.0;
      for (int i = lag; i < buffer.length; i++) {
        result += buffer[i] * buffer[i - lag];
      }
      return result;
    } else {
      throw Exception(
          "Lag parameter range is : -1 < lag < buffer size. Received [$lag] for buffer size of [${buffer.length}]");
    }
  }
}
