import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart';
import 'package:http/http.dart';
import 'package:speech_recognition/main_controller.dart';
import 'package:googleapis/docs/v1.dart' as docsApi;


import 'doc_helper.dart';

class DocsController extends GetxController {

  Future<void> _loadDocs() async {
    var _currentUser = Get.find<MainController>().googleUser.value;
    if (_currentUser == null) return;
    GoogleSignInAuthentication authentication =
    await _currentUser.authentication;

    // final client = Client(defaultHeaders: {
    //   'Authorization': 'Bearer ${authentication.accessToken}'
    // });
    //
    // DriveApi driveApi = DriveApi(Cli);
    // var files = await driveApi.files
    //     .list(q: 'mimeType=\'application/vnd.google-apps.document\'');
    // setState(() {
    //   _items = files.items;
    //   _loaded = true;
    // });
  }

  Future<void> loadDocs() async {
    var doc = await docsApi.DocsApi(MyClient()).documents.get('1r0Z4ErrEUNUvSdO-GnJPC8CRltHGPs9r53hf-YiA5ys');
    print(doc);
  }



  Future<docsApi.Document> saveDoc(docsApi.Document docModel, {String text = ''}) async{
    var doc = await docsApi.DocsApi(MyClient()).documents.create(docModel);
    await docsApi.DocsApi(MyClient()).documents
        .batchUpdate(docsApi.BatchUpdateDocumentRequest(
      requests: [docsApi.Request(
        insertText: docsApi.InsertTextRequest(
          text: text,
          location: docsApi.Location(index: 1),
        )
      )],
      writeControl: docsApi.WriteControl()
    ), doc.documentId!);
    return doc;
  }

}

class MyClient extends BaseClient{
  final Client _httpClient = Client();

  MyClient();

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    var auth = await Get.find<MainController>().googleUser.value!.authentication;
    request.headers.addAll({
      'Authorization': 'Bearer ${auth.accessToken}'
    });
    return _httpClient.send(request);
  }
}