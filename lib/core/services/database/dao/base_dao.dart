import 'package:sqflite/sqflite.dart';
import '../../security/encryption_service.dart';

abstract class BaseDao {
  final Database db;
  final EncryptionService encryptionService = EncryptionService();

  BaseDao(this.db);

  String encrypt(dynamic value) {
    if (value == null) return '';
    final strVal = value.toString();
    if (strVal.contains(':') && strVal.length > 20) {
      return strVal;
    }
    return encryptionService.encryptData(strVal);
  }

  String decrypt(String encrypted) {
    if (encrypted.isEmpty) return '';
    return encryptionService.decryptData(encrypted);
  }

  int decryptInt(String encrypted) {
    final val = decrypt(encrypted);
    return int.tryParse(val) ?? 0;
  }

  double decryptDouble(String encrypted) {
    final val = decrypt(encrypted);
    return double.tryParse(val) ?? 0.0;
  }
}
