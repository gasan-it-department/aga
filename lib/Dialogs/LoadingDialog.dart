import 'package:flutter/material.dart';

class LoadingDialog{
  bool _isShowing = false;

  BuildContext? dialogContext;
  StateSetter? _stateSetter;
  String _title = "loading...";

  void showLoadingDialog(BuildContext mainContext){
    _title = "loading...";
    _isShowing = true;
    showDialog(
      barrierDismissible: false,
      context: mainContext,
      builder: (BuildContext context) {
        dialogContext = context;
        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SizedBox(
                  width: 150,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        height: 10,
                      ),

                      const CircularProgressIndicator(
                        strokeCap: StrokeCap.round,
                        color: Colors.black,
                      ),

                      const SizedBox(
                        height: 10,
                      ),

                      Padding(
                        padding: const EdgeInsets.all(5),
                        child: StatefulBuilder(
                          builder: (context, setState){
                            _stateSetter = setState;
                            return Text(
                                _title
                            );
                          },
                        ),
                      ),
                    ],
                  )
              ),
            ),
          ),
        );
      },
    );
  }

  void dismiss(){
    if(!_isShowing) return;
    _isShowing = false;
    _stateSetter = null;
    if(dialogContext != null) Navigator.pop(dialogContext!);
    dialogContext = null;
  }

  void dismissWithContext(BuildContext context){
    if(!_isShowing) return;
    _isShowing = false;
    _stateSetter = null;
    if(dialogContext != null) Navigator.pop(context);
    dialogContext = null;
  }

  void updateTitle(String title){
    _title = title;
    if(!_isShowing) return;
    if(_stateSetter != null){
      try {
        _stateSetter!((){});
      } catch (_) {
        // Builder state was disposed — ignore.
      }
    }
  }
}
