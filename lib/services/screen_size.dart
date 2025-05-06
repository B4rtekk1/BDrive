import 'package:flutter/material.dart';

class ScreenSize {
  final BuildContext context;
  ScreenSize(this.context);

  Size getWindowsSize() => MediaQuery.of(context).size;

  double getWidth() => getWindowsSize().width;
  double getHeight() => getWindowsSize().height;
}