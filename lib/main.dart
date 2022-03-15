import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:get/get.dart';
import 'package:get/get_navigation/get_navigation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_recognition/main_controller.dart';
import 'package:speech_recognition/main_view.dart';
import 'package:speech_recognition/vosk_speech_recognizer.dart';

import 'consts.dart';

const generalAppBar =
    AppBarTheme(elevation: 0.4, centerTitle: false, titleSpacing: 20);

final theme = ThemeData(
  fontFamily: "Work Sans",
  appBarTheme: generalAppBar.copyWith(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      titleTextStyle: const TextStyle(
          fontFamily: "Work Sans",
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Colors.black)),
  focusColor: classicPurple,
  primarySwatch: Colors.deepPurple,
  primaryColor: classicPurple,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(GetMaterialApp(
    initialBinding: RootBindings(),
    home: MainView(),
  ));
}

class RootBindings extends Bindings {

  @override
  void dependencies() {
    Get.put(MainController());
  }
}
