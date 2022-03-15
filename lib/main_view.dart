import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_sound/public/util/flutter_sound_helper.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_recognition/main_controller.dart';

class MainView extends GetView<MainController> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            modelWidget(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Container(
                  alignment: Alignment.center,
                  padding: EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(8.0)
                  ),
                  child: Obx(
                    () => controller.processing.isTrue ? const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(Colors.red),
                      backgroundColor: Colors.transparent,
                    ) : Text(
                      controller.output.value
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: recordButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget modelWidget() {
    return Container(
      color: Colors.redAccent[100],
      padding: const EdgeInsets.all(8.0),
      child: Obx(
        () {
          if (controller.modelProgress.value == 0) {
            return InkWell(
                onTap: () {
                  if (controller.modelProgress.value == 0) {
                    controller.loadModel();
                  }
                },
                child: Container(
                alignment: Alignment.center,
                padding: EdgeInsets.all(8.0),
                child: Text('Tap here to load model')));
          }
          if (controller.modelProgress.value == 1.0) {
            return InkWell(
              onTap: () {
                controller.modelProgress.trigger(0);
              },
              child: Container(
                  alignment: Alignment.center,
                  padding: EdgeInsets.all(8.0),
                  child: Text(controller.modelPath.split('/').last)),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: LinearProgressIndicator(
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                    value: controller.modelProgress.value,
                    backgroundColor: Colors.white,
                  ),
                ),
                Text(controller.modelProgressMessage.value),
              ],
            ),
          );
        }
        ),
    );

  }

  Widget recordButton() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: IconButton(onPressed: (){}, icon: const Icon(Icons.attach_file, color: Colors.transparent,)),
        ),
        Flexible(
          child: InkWell(
            onTap: () {
              controller.recordPressed();
            },
            child: Container(
              width: 60,
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.redAccent
              ),
              child: Obx(() => controller.recording.isTrue ? FittedBox(child: Text('${controller.recordingSeconds}', style: const TextStyle(color: Colors.white),)) :  const Icon(Icons.mic, color: Colors.white, size: 24,)),
            ),
          ),
        ),
        Flexible(
          child: IconButton(onPressed: () async {
            controller.processFile();
          }, icon: const Icon(Icons.attach_file, color: Colors.black38,)),
        ),
      ],
    );
  }
}