import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import '../Dialogs/ClassicDialog.dart';

class AgaInAppUpdater {
  final _classicDialog = ClassicDialog();

  Future<void> checkForUpdates(BuildContext context, String userAccount) async {
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      AppUpdateInfo updateInfo = await InAppUpdate.checkForUpdate();
      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        if (updateInfo.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
          return;
        }

        _classicDialog.setTitle("Update Required");
        _classicDialog.setMessage(
          "A new version is available. Please update the app from Google Play to continue.",
        );
        _classicDialog.setCancelable(false);
        _classicDialog.setPositiveMessage("Close");
        if (context.mounted) {
          _classicDialog.showOnButtonDialog(context, () {
            _classicDialog.dismissDialog();
          });
        }
      }
    } catch (e) {
      if(kDebugMode || userAccount == "rizzabhb24024@gmail.com"){
        debugPrint("Debug mode detected. Bypassing the in-app-update.");
      }else{
        _classicDialog.setTitle("Update Error");
        _classicDialog.setMessage("Error: ${e.toString()}");
        _classicDialog.setCancelable(false);
        _classicDialog.setPositiveMessage("Close");
        if(context.mounted){
          _classicDialog.showOnButtonDialog(context, (){
            _classicDialog.dismissDialog();
          });
        }
      }
    }
  }
}
