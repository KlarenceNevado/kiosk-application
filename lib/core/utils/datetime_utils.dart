import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';

class DateTimeUtils {
  /// Converts any UTC or local DateTime to Asia/Manila (PHT)
  static DateTime toPHT(DateTime dateTime) {
    try {
      final manila = tz.getLocation('Asia/Manila');
      return tz.TZDateTime.from(dateTime, manila);
    } catch (e) {
      // Fallback to local if timezone db not initialized
      return dateTime.toLocal();
    }
  }

  /// Formats a DateTime into a PHT string with a given pattern
  static String formatPHT(DateTime dateTime,
      [String pattern = 'MMM dd, yyyy h:mm a']) {
    return DateFormat(pattern).format(toPHT(dateTime));
  }
}
