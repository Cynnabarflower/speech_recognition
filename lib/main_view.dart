import 'dart:io';

import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:get/get.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:speech_recognition/docs_controller.dart';
import 'package:speech_recognition/main_controller.dart';

class MainView extends GetView<MainController> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.redAccent[100],
        title: modelWidget(),
        centerTitle: true,
        actions: [
          Obx(
            () => IconButton(
              icon: controller.googleUser.value == null
                  ? const Icon(
                      Icons.login,
                      color: Colors.white,
                    )
                  : CircleAvatar(
                      foregroundImage:
                          controller.googleUser.value?.photoUrl == null
                              ? null
                              : NetworkImage(
                                  controller.googleUser.value!.photoUrl!),
                      backgroundColor: Colors.transparent),
              onPressed: controller.signIn,
            ),
          )
        ],
      ),
      drawer: drawer(),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.topCenter,
                fit: StackFit.expand,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Container(
                      alignment: Alignment.topCenter,
                      padding: EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8.0)),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: 200),
                        child: Obx(
                          () => quill.QuillEditor.basic(
                            controller: controller.qcontroller.value,
                            readOnly: false,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    child: IconButton(
                        onPressed: () {
                          // controller.qcontroller.formatText(1, 2, quill.ColorAttribute('#ffff00'));
                          // controller.textController.value.clear();
                          controller.users.clear();
                          controller.recordingList.clear();
                          controller.qcontroller.value.ignoreFocusOnTextChange = true;
                          controller.qcontroller.value.clear();
                          controller.currentUser = null;
                          controller.currentInput.value = '';
                          controller.usersCount = 0;
                          controller.qcontroller.value.notifyListeners();
                        },
                        icon: const Icon(
                          Icons.clear,
                          color: Colors.black54,
                        )),
                    right: 8.0,
                    top: 8.0,
                  ),
                  Positioned(
                    child: Column(
                      children: [
                        GestureDetector(
                            onTap: () {
                              controller.qcontroller.value.moveCursorToStart();
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: const Icon(
                                Icons.keyboard_arrow_up_outlined,
                                color: Colors.black54,
                              ),
                            )),
                        GestureDetector(
                            onTap: () {
                              controller.qcontroller.value.moveCursorToEnd();
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(
                                  right: 8.0, bottom: 8.0),
                              child: const Icon(
                                Icons.keyboard_arrow_down_outlined,
                                color: Colors.black54,
                              ),
                            )),
                      ],
                    ),
                    right: 8.0,
                    bottom: 8.0,
                  )
                ],
              ),
            ),
            SizedBox(
              height: 60 + 32,
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 20.0, right: 20.0),
                      child: Container(
                        height: 60,
                        child: SingleChildScrollView(
                            reverse: true,
                            child: Obx(() => Text(controller.currentInput.value))),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      alignment: Alignment.bottomCenter,
                      child: SizedBox(
                        height: 32 + 30,
                        child: Obx(
                              () => ListView(
                            controller: controller.usersListController,
                            scrollDirection: Axis.horizontal,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    height: 10,
                                    width: 20,
                                    color: Colors.white.withOpacity(0.01),
                                  ),
                                  IconButton(
                                      onPressed: () {
                                        controller.currentUser = controller.addUser();
                                        controller.users.refresh();
                                        controller.usersListController.animateTo(controller.usersListController.position.maxScrollExtent, duration: Duration(milliseconds: 100), curve: Curves.bounceOut);
                                      },
                                      icon: const Icon(Icons.person_add)),
                                ],
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    height: 10,
                                    width: 20,
                                    color: Colors.white.withOpacity(0.01),
                                  ),
                                  IconButton(
                                      onPressed: () {
                                        controller.currentUser = null;
                                        controller.users.refresh();
                                      },
                                      icon: Icon(
                                        Icons.person_search,
                                        color: controller.currentUser == null
                                            ? Colors.redAccent[100]
                                            : null,
                                      )),
                                ],
                              ),
                              ...controller.users.keys.map((e) => Container(
                                padding: EdgeInsets.only(right: 4.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      height: 20,
                                      width: 20,
                                      color: Colors.white.withOpacity(0.01),
                                    ),
                                    SizedBox(
                                      height: 30,
                                      child: DragTarget(
                                        onWillAccept: (data) => data != e,
                                        onAccept: (o) {
                                          if (controller.users.containsKey(o)) {
                                            var anotherUser = controller.users[o]!;
                                            controller.users[e]!.vectors.addAll(anotherUser.vectors);
                                            controller.users.remove(o);
                                          }
                                        },
                                        builder: (context, candidateData, rejectedData) =>
                                            Draggable(
                                              data: e,
                                              feedback: Card(
                                                child: Container(
                                                  height: 32,
                                                  alignment: Alignment.center,
                                                  decoration: BoxDecoration(
                                                      color: controller.currentUser == e
                                                          ? Colors.redAccent[100]
                                                          : Colors.transparent,
                                                      borderRadius: BorderRadius.circular(4.0)
                                                  ),
                                                  margin: EdgeInsets.only(right: 1.0),
                                                  padding: EdgeInsets.all(8.0),
                                                  child: Text(e),
                                                ),
                                              ),
                                              child: GestureDetector(
                                                onTap: () {
                                                  controller.currentUser = e;
                                                  controller.users.refresh();
                                                },
                                                onLongPress: () {
                                                  showDialog(context: context, builder: (c) {
                                                    var name = e;
                                                    Color color = controller.users[e]!.color;
                                                    return Center(
                                                      child: Column(
                                                        mainAxisSize: MainAxisSize.min,
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          Container(
                                                            decoration: BoxDecoration(
                                                              borderRadius: BorderRadius.circular(8),
                                                              color: Colors.white,
                                                            ),
                                                            width: 300,
                                                            padding: EdgeInsets.all(8.0),
                                                            alignment: Alignment.center,
                                                            child: Column(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                Material(
                                                                  child: TextField(
                                                                    controller: TextEditingController()..text = name,
                                                                    onChanged: (v) {
                                                                      name = v;
                                                                    },
                                                                  ),
                                                                ),
                                                                SizedBox(height: 12.0),
                                                                ColorPicker(
                                                                  onColorChanged: (v){
                                                                    color = v;
                                                                  },
                                                                ),
                                                                Row(
                                                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                                  children: [
                                                                    MaterialButton(onPressed: (){
                                                                      controller.users[e]!.color = color;
                                                                      if (name != e) {
                                                                        if (controller.currentUser == e) {
                                                                          controller.currentUser = name;
                                                                        }
                                                                        controller.users[name] =
                                                                        controller.users[e]!;
                                                                        controller.users[name]!.name =
                                                                            name;
                                                                        controller.users.remove(e);
                                                                      }
                                                                      Get.back();
                                                                    }, child: Icon(Icons.done),),
                                                                    SizedBox(width: 32,),
                                                                    MaterialButton(onPressed: (){
                                                                      controller.users.remove(e);
                                                                      Get.back();
                                                                    }, child: Icon(Icons.delete),)
                                                                  ],
                                                                )
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  });
                                                },
                                                child: Container(
                                                  alignment: Alignment.center,
                                                  decoration: BoxDecoration(
                                                      color: controller.currentUser == e
                                                          ? Colors.redAccent[100]
                                                          : Colors.transparent,
                                                      borderRadius: BorderRadius.circular(4.0)
                                                  ),
                                                  margin: EdgeInsets.only(right: 4.0),
                                                  padding: EdgeInsets.all(8.0),
                                                  child: Text(e, style: TextStyle(color: controller.users[e]?.color),),
                                                ),
                                              ),
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ))
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
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
      width: 200,
      child: Obx(() {
        return Column(
          children: [
            if (controller.modelProgress.value == 0 ||
                controller.modelProgress.value == 1.0)
              DropdownButton<ModelVariant?>(
                isExpanded: true,
                value: controller.currentModelVariant.value,
                underline: SizedBox(),
                icon: SizedBox(),
                items: [
                  DropdownMenuItem(
                      child: Container(
                          alignment: Alignment.center,
                          padding: EdgeInsets.all(8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Text(
                                  'Full model',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                              if (controller.isModelLoaded(ModelVariant.big))
                                IconButton(
                                    onPressed: () async {
                                      await Directory((await controller
                                              .getModelPath(ModelVariant.big))!)
                                          .delete(recursive: true);
                                      controller.updateModelsLoaded();
                                    },
                                    icon: Icon(
                                      Icons.delete,
                                      color: Colors.black54,
                                    ))
                            ],
                          )),
                      value: ModelVariant.big),
                  DropdownMenuItem(
                    child: Container(
                        alignment: Alignment.center,
                        padding: EdgeInsets.all(8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Text(
                                'Small model',
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                            if (controller.isModelLoaded(ModelVariant.small))
                              IconButton(
                                  onPressed: () async {
                                    await Directory((await controller
                                            .getModelPath(ModelVariant.small))!)
                                        .delete(recursive: true);
                                    controller.updateModelsLoaded();
                                  },
                                  icon: Icon(
                                    Icons.delete,
                                    color: Colors.black54,
                                  ))
                          ],
                        )),
                    value: ModelVariant.small,
                  ),
                  DropdownMenuItem(
                    child: Container(
                        alignment: Alignment.centerLeft,
                        padding: EdgeInsets.all(8.0),
                        child: const Text(
                          'Модель не загружена',
                          style: TextStyle(fontSize: 14),
                        )),
                    value: null,
                  ),
                ],
                onChanged: (e) {
                  if (e != null) {
                    controller.loadModel(e);
                  }
                },
              ),
            if (controller.modelProgress.value > 0 &&
                controller.modelProgress.value < 1.0)
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: InkWell(
                  onTap: () {
                    controller.isDownloading = false;
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: LinearProgressIndicator(
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(Colors.red),
                          value: controller.modelProgress.value,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      Text(
                        controller.modelProgressMessage.value,
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }

  Widget recordButton() {
    double? waitingData;
    return Stack(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                  onPressed: () {
                    // controller.sha
                    // controller.textController.value.clear();
                    var text = controller.qcontroller.value.document.getPlainText(0, controller.qcontroller.value.document.length);
                    Share.share(text);
                    },
                  icon: const Icon(
                    Icons.share,
                    color: Colors.black54,
                  )),
              IconButton(
                  onPressed: () {
                    if (controller.googleUser.value != null) {
                      controller.addToDrive();
                    } else {
                      Get.snackbar('Ooops', 'Надо войти в аккаунт', snackPosition: SnackPosition.BOTTOM);
                    }
                  },
                  icon: const Icon(
                    Icons.add_to_drive,
                    color: Colors.black54,
                  )),
            ],
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: StreamBuilder(
              stream: controller.noiseController.stream,
              builder: (c, AsyncSnapshot<double?> s) {
                var noise = s.data ?? 0.0;
                if (!noise.isFinite) {
                  noise = 0.0;
                }
                return Obx(
                  () => AnimatedContainer(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withOpacity(0.3),
                          spreadRadius: controller.recording.isTrue
                              ? (0.2 * noise)
                              : 0.0,
                        )
                      ],
                    ),
                    duration: const Duration(milliseconds: 100),
                    child: ClipOval(
                      child: Material(
                        child: InkWell(
                          onTap: () {
                            controller.recordPressed();
                          },
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: 50,
                              maxWidth: 50,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(8.0),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                              child: FittedBox(
                                  alignment: Alignment.center,
                                  fit: BoxFit.fill,
                                  child: Obx(() {
                                    if (controller.recording.isTrue) {
                                      var minutes =
                                          Duration(seconds: controller.recordingSeconds.value)
                                              .inMinutes;
                                      var seconds =
                                          controller.recordingSeconds.value - minutes * 60;
                                      return FittedBox(
                                          child: Text(
                                            minutes == 0
                                                ? '$seconds'
                                                : '$minutes:${seconds.toString().padLeft(2, '0')}',
                                            style: const TextStyle(color: Colors.white),
                                          ));
                                    }
                                    return const Icon(
                                      Icons.mic,
                                      color: Colors.white,
                                      size: 24,
                                    );
                                  })),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
                    IconButton(
                    onPressed: () async {
                      var ignoreFocus = !controller.ignoreFocus.isTrue;
                      controller.qcontroller.value.ignoreFocusOnTextChange = ignoreFocus;
                      controller.ignoreFocus.trigger(ignoreFocus);
                      if (ignoreFocus) {
                        FocusScope.of(Get.context!).unfocus();
                      }
                    },
                    icon: Obx(
                      () => Icon(
                        Icons.keyboard,
                        color: controller.ignoreFocus.isFalse ? Colors.green.withOpacity(0.54) : Colors.black38,
                      ),
                    ),
              ),
              IconButton(
                  onPressed: () async {
                    controller.processFile();
                  },
                  icon: const Icon(
                    Icons.attach_file,
                    color: Colors.black38,
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Widget drawer() {
    return Drawer(
      elevation: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SizedBox(height: 16,),
              Obx(() => Text('Min distance for diarization ${controller.minDist.value}')),
              Obx(() => Slider(value: controller.minDist.value, min: 0.01, max: 0.3, divisions: 29, onChanged: (v) => controller.minDist.trigger((v * 100).roundToDouble()/100))),
              Padding(
                padding: const EdgeInsets.only(
                    top: 16.0, bottom: 8.0, left: 16.0, right: 16.0),
                child: Row(
                  children: [
                    Expanded(child: Text('Files')),
                    IconButton(
                      icon: Icon(Icons.refresh),
                      onPressed: () {
                        controller.loadFiles();
                        // Get.find<DocsController>().loadDocs();
                      },
                    )
                  ],
                ),
              ),
              Expanded(
                child: Obx(
                  () => ListView(
                    children: [
                      ...controller.files.map((e) => ListTile(
                            title: Text(
                              basename(e.path),
                              style: TextStyle(color: Colors.black),
                            ),
                            trailing: Wrap(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.share),
                                  onPressed: () {
                                    Share.shareFiles([e.path]);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () {
                                    File(e.path).deleteSync();
                                    controller.loadFiles();
                                  },
                                ),
                              ],
                            ),
                            onLongPress: () {
                              OpenFile.open(e.path);
                              Get.back();
                            },
                            onTap: () async {
                              var dir = Directory(
                                  '${(await getApplicationDocumentsDirectory()).path}/open')
                                ..createSync();
                              dir.listSync().forEach((element) {
                                element.deleteSync();
                              });
                              showDialog(
                                context: Get.context!,
                                builder: (context) {
                                  return Center(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (File(e.path.replaceAll('.txt', '.wav')).existsSync()) Padding(
                                            padding: const EdgeInsets.only(bottom: 2.0),
                                            child: Material(
                                              child: Container(
                                                width: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                    0.9,
                                                child: IconButton(icon: Icon(Icons.play_arrow), onPressed: () {
                                                  OpenFile.open(e.path.replaceAll('.txt', '.wav'));
                                                }),
                                              ),
                                            ),
                                          ),
                                          StreamBuilder(
                                            stream:
                                                File(e.path).readAsLines().asStream(),
                                            builder: (context,
                                                AsyncSnapshot<List<String>> snapshot) {
                                              if (!snapshot.hasData ||
                                                  snapshot.data == null) {
                                                return Material(
                                                  child: Container(
                                                    width: MediaQuery.of(context)
                                                            .size
                                                            .width *
                                                        0.9,
                                                    alignment: Alignment.center,
                                                    child:
                                                        const CircularProgressIndicator(),
                                                  ),
                                                );
                                              }
                                              return Material(
                                                child: Container(
                                                  height: MediaQuery.of(context)
                                                          .size
                                                          .height *
                                                      0.6,
                                                  width: MediaQuery.of(context)
                                                          .size
                                                          .width *
                                                      0.9,
                                                  alignment: Alignment.topLeft,
                                                  padding: const EdgeInsets.all(4.0),
                                                  child: ListView.builder(
                                                    itemCount: snapshot.data!.length,
                                                    itemBuilder: (context, index) =>
                                                        ListTile(
                                                      visualDensity:
                                                          VisualDensity.compact,
                                                      title:
                                                          Text(snapshot.data![index]),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2.0),
                                            child: Material(
                                              child: Container(
                                                width: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                    0.9,
                                                child: IconButton(icon: Icon(Icons.done), onPressed: () {
                                                  Get.back();
                                                }),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ))
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
