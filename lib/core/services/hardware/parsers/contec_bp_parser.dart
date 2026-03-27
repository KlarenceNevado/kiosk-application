import 'dart:typed_data';

class ContecBpParser {
  /// Parses the serial data from a CONTEC08A Blood Pressure Monitor.
  /// 
  /// The CONTEC08A typically sends data in a binary format (e.g., 7 or 9 byte packets).
  /// This parser handles real-time pressure and final results.
  static Map<String, dynamic>? parse(Uint8List bytes) {
    if (bytes.length < 7) return null;

    // Header check for CONTEC binary protocol (often starts with 0x02 or similar)
    // Note: Actual protocol varies by firmware version.
    
    // Example Real-time Pressure Packet (7 bytes):
    // [0] Header, [1] Type, [2] High Byte, [3] Low Byte, ...
    if (bytes[0] == 0x02 && bytes.length == 7) {
      final int pulse = ((bytes[2] & 0x7F) << 7) | (bytes[3] & 0x7F);
      return {
        'type': 'realtime',
        'pressure': pulse,
      };
    }

    // Example Result Packet (9+ bytes):
    // [0] Header, [1] Type, [2] Systolic, [3] Diastolic, [4] Pulse, ...
    if (bytes[0] == 0x01 && bytes.length >= 9) {
      return {
        'type': 'result',
        'sys': bytes[2],
        'dia': bytes[3],
        'pulse': bytes[4],
      };
    }

    return null;
  }
}
