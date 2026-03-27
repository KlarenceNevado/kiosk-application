import 'dart:typed_data';

class SpO2Parser {
  /// Parses the CMS50D+ 5-byte pulse oximeter binary format
  /// 
  /// Protocol:
  /// Byte 1: 0x81 (Header)
  /// Byte 2: Signal Strength/Status
  /// Byte 3: Pulse Waveform
  /// Byte 4: Pulse Rate (BPM)
  /// Byte 5: SpO2 (%)
  static Map<String, int>? parse(Uint8List bytes) {
    // Protocol requires 5 bytes per packet
    if (bytes.length < 5) return null;
    
    // Header check
    if (bytes[0] != 0x81) return null;
    
    // CMS50D+ specifics:
    // Some versions use Bit 7 (0b10000000) as header marker for all bytes
    // For now, we use a simple header-based packet split:
    final int bpm = bytes[3] & 0x7F; // Bit 0-6 is BPM
    final int spo2 = bytes[4] & 0x7F; // Bit 0-6 is SpO2
    
    if (spo2 > 0 && spo2 <= 100 && bpm >= 30 && bpm <= 250) {
      return {'spo2': spo2, 'bpm': bpm};
    }
    return null;
  }
}

