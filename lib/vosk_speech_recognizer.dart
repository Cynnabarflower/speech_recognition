import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_archive/flutter_archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'consts.dart';

const androidPlatform = MethodChannel("channel");

/// Returns null if success
Future<String?> voskInitModel(String path) async {
  if (!Platform.isAndroid) {
    return "Not Android";
  }
  try {
    // TODO: is this fallible to the sandbox path changing?
    final res = await androidPlatform.invokeMethod("initModel", {"path": path});
    if (res != null) {
      return res.toString();
    }
    return null;
  } catch (e) {
    return e.toString();
  }
}
