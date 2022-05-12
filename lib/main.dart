import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:speech_recognition/docs_controller.dart';
import 'package:speech_recognition/main_controller.dart';
import 'package:speech_recognition/main_view.dart';

const androidPlatform = MethodChannel("channel");


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
    Get.put(DocsController());
  }
}
