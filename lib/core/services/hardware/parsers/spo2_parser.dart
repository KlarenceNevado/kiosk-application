import 'dart:typed_data';

class SpO2ParserResult {
  final Map<String, int> data;
  final int bytesConsumed;
  SpO2ParserResult(this.data, this.bytesConsumed);
}

class SpO2Parser {
  /// Parses the CMS50D+ 5-byte pulse oximeter binary format from a buffer.
  /// 
  /// Protocol:
  /// Byte 1: Header (Bit 7 is always 1, usually 0b10000001 or 0x81)
  /// Byte 2-5: Data (Bit 7 is usually 0)
  static SpO2ParserResult? parse(Uint8List buffer) {
    if (buffer.length < 5) return null;

    for (int i = 0; i <= buffer.length - 5; i++) {
      // CMS50D+ Protocol Sync: The first byte of a packet has Bit 7 set.
      // In some modes, it's exactly 0x81.
      if ((buffer[i] & 0x80) != 0) {
        final packet = buffer.sublist(i, i + 5);
        
        // Basic validation: the following 4 bytes should NOT have Bit 7 set 
        // (This depends on the specific CMS50D+ protocol version)
        bool isValid = true;
        for (int j = 1; j < 5; j++) {
          if ((packet[j] & 0x80) != 0) {
            isValid = false;
            break;
          }
        }

        if (isValid) {
          final int bpm = packet[3] & 0x7F;
          final int spo2 = packet[4] & 0x7F;

          if (spo2 > 0 && spo2 <= 100 && bpm >= 30 && bpm <= 250) {
            return SpO2ParserResult(
              {'spo2': spo2, 'bpm': bpm},
              i + 5, // Consumed up to the end of this packet
            );
          }
        }
      }
    }
    
    // If we have a lot of junk at the start, we might want to clear it, 
    // but the SerialService should handle the 'bytesConsumed' logic.
    return null;
  }
}

