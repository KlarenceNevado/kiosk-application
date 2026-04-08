import 'dart:convert';
import 'dart:typed_data';

class WeightParser {
  /// Simple ASCII parser for common electronic scales
  /// Expected format examples: "70.5kg", "ST,GS,  70.50kg", "70.50"
  static double? parse(Uint8List bytes) {
    try {
      final text = utf8.decode(bytes).trim();
      // Extract numeric part using regex
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
