
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class Utility {

  static const String _hexChars = '0123456789abcdef';

  static Uint8List? decodeHexImage(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    try {
      final String clean = hex.startsWith('\\x') ? hex.substring(2) : hex;
      final int length = clean.length ~/ 2;
      final Uint8List bytes = Uint8List(length);
      for (int i = 0; i < length; i++) {
        bytes[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
      }
      return bytes;
    } catch (e) {
      debugPrint("Hex decode error: $e");
      return null;
    }
  }

  static String encodeHexImage(Uint8List bytes) {
    final StringBuffer buf = StringBuffer('\\x');
    for (final int b in bytes) {
      buf.writeCharCode(_hexChars.codeUnitAt((b >> 4) & 0x0F));
      buf.writeCharCode(_hexChars.codeUnitAt(b & 0x0F));
    }
    return buf.toString();
  }


  void printLog(String message){
    if(kDebugMode){
      if(kIsWeb){
        debugPrint(message);
      }else{
        print(message);
      }
    }
  }

  String generateUniqueID(){
    return DateTime.now().microsecondsSinceEpoch.toString();
  }

  int getCurrentMSEpochTime() {
    return DateTime.now().millisecondsSinceEpoch;
  }

  String getCurrentGlobalVersion(){
    return "1.2.3 alpha";
  }

  String formatEpochToTime(int epochSeconds) {
    if (epochSeconds == 0) return "--:--";
    DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(epochSeconds);
    return DateFormat('MMM dd, yyyy hh:mm a').format(dateTime);
  }

  String getEpochTimeAgo(int epochSeconds) {
    if (epochSeconds == 0) return "";

    final now = DateTime.now();
    final eventTime = DateTime.fromMillisecondsSinceEpoch(epochSeconds);
    final diff = now.difference(eventTime);

    if (diff.isNegative) return "In queue";
    if (diff.inSeconds < 60) return "${diff.inSeconds}s ago";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";

    return DateFormat('MMM dd').format(eventTime);
  }

  Future<bool> hasInternetConnection() async {
    try {
      if(kIsWeb){
        return true;
      }
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
    } on SocketException catch (_) {
      return false;
    }
    return false;
  }

  double getMaxScreenSize(){
    return 840.0;
  }

  double getMaxDialogSize(){
    return 500.0;
  }

  String getTermsAndPrivacyPolicyLink(){
    return "https://sites.google.com/view/terms-conditions-aga-app/home";
  }

  String getCurrentReadableDate(String format){
    DateTime now = DateTime.now();
    String formattedDate = DateFormat(format).format(now);
    return formattedDate;
  }

  String formatPrice(dynamic price) {
    if (price == null) return "0.00";
    final num value = price is num ? price : (num.tryParse(price.toString()) ?? 0);
    final formatter = NumberFormat("#,##0.00", "en_US");
    return formatter.format(value);
  }

  static const Map<String, int> marinduqueZipCodes = {
    'Boac': 4900,
    'Mogpog': 4901,
    'Santa Cruz': 4902,
    'Torrijos': 4903,
    'Buenavista': 4904,
    'Gasan': 4905,
  };
}
