import 'dart:typed_data';

class ContecBpResult {
  final Map<String, dynamic> data;
  final int bytesConsumed;
  ContecBpResult(this.data, this.bytesConsumed);
}

class ContecBpParser {
  /// Parses binary data from CONTEC08A Blood Pressure Monitor with buffer support.
  /// Handles both Serial (raw) and HID (prefixed) packets.
  static ContecBpResult? parse(Uint8List buffer) {
    if (buffer.length < 7) return null;

    // HID Check: If the buffer starts with 0x00 (Report ID), we shift our window.
    int offset = 0;
    if (buffer[0] == 0x00 && buffer.length > 7) {
      // Look for the header at index 1 instead of 0
      offset = 1;
    }

    for (int i = offset; i <= buffer.length - 7; i++) {
      // CONTEC Sync: Real-time packets often start with 0x02 (Length 7)
      // Result packets often start with 0x01 (Length 9+)

      // REAL-TIME PRESSURE (7 Bytes)
      if (buffer[i] == 0x02 && (buffer.length - i) >= 7) {
        // [0] Header, [1] Type, [2] Pressure High, [3] Pressure Low, ...
        // Note: Contec uses 7-bit values for bits 0-6. Bit 7 might be status.
        final int pressure =
            ((buffer[i + 2] & 0x7F) << 7) | (buffer[i + 3] & 0x7F);

        if (pressure < 300) {
          // Sanity check
          return ContecBpResult(
            {'type': 'realtime', 'pressure': pressure},
            i + 7,
          );
        }
      }

      // FINAL RESULT (9 Bytes)
      if (buffer[i] == 0x01 && (buffer.length - i) >= 9) {
        // [0] Header, [1] ResultType, [2] Sys, [3] Dia, [4] Pulse, ...
        // Check for error codes (CONTEC often encodes these in the result bytes when measurement fails)
        final int sys = buffer[i + 2];
        final int dia = buffer[i + 3];

        if (sys == 0 || sys > 250) {
          return ContecBpResult(
            {
              'type': 'error',
              'error_code': sys,
              'message': _translateBpError(sys),
            },
            i + 9,
          );
        }

        return ContecBpResult(
          {
            'type': 'result',
            'sys': sys,
            'dia': dia,
            'pulse': buffer[i + 4],
          },
          i + 9,
        );
      }
    }

    return null;
  }

  static String _translateBpError(int code) {
    switch (code) {
      case 0x0E:
        return "Cuff too loose";
      case 0x0F:
        return "Movement detected";
      case 0x10:
        return "Signal too weak";
      case 0x11:
        return "Measurement timeout";
      case 0x12:
        return "Overpressure detected";
      default:
        return "Measurement failed (E$code)";
    }
  }
}
