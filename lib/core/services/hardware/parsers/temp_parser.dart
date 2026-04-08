import 'dart:convert';
import 'dart:typed_data';

class TempParser {
  /// Parses body temperature from IR sensors
  static double? parse(Uint8List bytes) {
    try {
      final text = utf8.decode(bytes).trim();
      final match = RegExp(r"(\d+\.?\d*)").firstMatch(text);
      if (match != null) {
        return double.tryParse(match.group(1)!);
      }
    } catch (e) {
      return null;
    }
    return null;
  }
}
