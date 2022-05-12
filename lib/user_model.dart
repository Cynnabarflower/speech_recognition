import 'dart:ui';

import 'package:ml_linalg/vector.dart';

class UserModel {
  String name;
  Color color;
  List<Vector> vectors;

  UserModel(this.name, Color? color1, this.vectors) : color = color1 ?? getColorFromName(name);

  static Color getColorFromName(String name) {
    return Color.fromARGB(
        255,
        (name.hashCode + 39) % 100 + 40,
        (name.hashCode + 23) % 120 + 40,
        (name.hashCode + 74) % 120 + 40
    );
  }

}