import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class ColorTextEditingController extends TextEditingController {

  Map<String, TextStyle>? textStyles;
  List<TextSpan> children = [];
  String visibleText = '';


  static const styleToken = '<STYLE00>';
  var regexp = RegExp('<STYLE[^\>][^\>]>(.|\n)*?');
  var regexpToken = RegExp('<STYLE[^\>][^\>]>');

  ColorTextEditingController({this.textStyles, String? text}) : super(text: text) {
    textStyles ??= {
      '<STYLE00>': TextStyle(color: Colors.red),
      '<STYLE01>': TextStyle(color: Colors.green),
      '<STYLE02>': TextStyle(color: Colors.blue),
    };
  }
  @override
  set text(String newText) {

    super.text = newText;
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style , required bool withComposing}) {
    return TextSpan(style: style, children: children);
  }
}