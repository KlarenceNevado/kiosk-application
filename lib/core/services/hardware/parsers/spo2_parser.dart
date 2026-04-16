import 'dart:typed_data';

class SpO2ParserResult {
  final Map<String, int> data;
  final int bytesConsumed;
  SpO2ParserResult(this.data, this.bytesConsumed);
}

class SpO2Parser {
  /// Parses the CMS50D+ 9-byte pulse oximeter binary format from a buffer.
  ///
  /// Protocol (9-byte version):
  /// Byte 0: Header (Bit 7 is always 1)
  /// Byte 4: SpO2 (0-100)
  /// Byte 5: Pulse Rate (0-254)
  static SpO2ParserResult? parse(Uint8List buffer) {
    if (buffer.length < 9) return null;

    for (int i = 0; i <= buffer.length - 9; i++) {
      // CMS50D+ Protocol Sync: The first byte of a packet has Bit 7 set.
      if ((buffer[i] & 0x80) != 0) {
        final packet = buffer.sublist(i, i + 9);

        // Extract values from indices specified in directive
        final int spo2 = packet[4] & 0x7F;
        final int bpm = packet[5] & 0x7F;

        // Validation for the 9-byte format
        if (spo2 > 0 && spo2 <= 100 && bpm >= 30 && bpm <= 250) {
          return SpO2ParserResult(
            {'spo2': spo2, 'bpm': bpm},
            i + 9, // Consumed 9 bytes
          );
        }
      }
    }

    // Handle legacy 5-byte format as secondary fallback if needed,
    // but the directive specifically requested 9-byte implementation.
    return null;
  }
}
