import 'dart:core';
import 'package:flutter/foundation.dart';
import 'Utility.dart';

class BuildStatus{

  bool isDebugMode() {
    if (kDebugMode) {
      Utility().printLog("Debug mode.");
      return true;
    } else if (kReleaseMode) {
      Utility().printLog("Release mode.");
      return false;
    }
    return true;
  }

}
