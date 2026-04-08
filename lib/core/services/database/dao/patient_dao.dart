import 'package:sqflite/sqflite.dart';
import '../../../../features/auth/models/user_model.dart';
import 'base_dao.dart';

class PatientDao extends BaseDao {
  PatientDao(super.db);

  Future<void> insertPatient(User user) async {
    final map = user.toMap();

    final encryptedMap = <String, dynamic>{
      'id': map['id'],
      'first_name': map['first_name'] ?? map['firstName'],
      'last_name': map['last_name'] ?? map['lastName'],
      'middle_initial': map['middle_initial'] ?? map['middleInitial'],
      'sitio': map['sitio'],
      'phone_number': encrypt(map['phone_number'] ?? map['phoneNumber']),
      'pin_code': encrypt(map['pin_code'] ?? map['pin_code'] ?? map['pinCode']),
      'gender': map['gender'],
      'date_of_birth': map['date_of_birth'] ?? map['dateOfBirth'],
      'parent_id': map['parent_id'] ?? map['parentId'],
      'created_at': map['created_at'] ?? DateTime.now().toIso8601String(),
      'updated_at': map['updated_at'] ?? DateTime.now().toIso8601String(),
      'is_deleted':
          (map['is_deleted'] == true || map['is_deleted'] == 1) ? 1 : 0,
      'is_active': (map['is_active'] == true ||
              map['is_active'] == 1 ||
              map['isActive'] == true ||
              map['isActive'] == 1)
          ? 1
          : 0,
      'is_synced': (map['is_synced'] == true || map['is_synced'] == 1) ? 1 : 0,
      'pin_hash': map['pin_hash'],
      'pin_salt': map['pin_salt'],
    };

    await db.insert('patients', encryptedMap,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<User>> getPatients() async {
    final result = await db.query('patients',
        where: 'is_deleted = ?', whereArgs: [0], orderBy: 'last_name ASC');
    return result.map((json) {
      final decrypted = Map<String, dynamic>.from(json);
      decrypted['phoneNumber'] =
          decrypt(json['phone_number']?.toString() ?? '');
      decrypted['pinCode'] = decrypt(json['pin_code']?.toString() ?? '');
      decrypted['pin_hash'] = json['pin_hash'];
      decrypted['pin_salt'] = json['pin_salt'];
      return User.fromMap(decrypted);
    }).toList();
  }

  Future<User?> getPatientById(String id) async {
    final maps = await db.query('patients', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      final decrypted = Map<String, dynamic>.from(maps.first);
      decrypted['phoneNumber'] =
          decrypt(maps.first['phone_number']?.toString() ?? '');
      decrypted['pinCode'] = decrypt(maps.first['pin_code']?.toString() ?? '');
      decrypted['pin_hash'] = maps.first['pin_hash'];
      decrypted['pin_salt'] = maps.first['pin_salt'];
      return User.fromMap(decrypted);
    }
    return null;
  }

  Future<void> updatePatient(User user) async {
    final map = user.toMap();
    final encryptedMap = <String, dynamic>{
      'id': map['id'],
      'first_name': map['first_name'] ?? map['firstName'],
      'last_name': map['last_name'] ?? map['lastName'],
      'middle_initial': map['middle_initial'] ?? map['middleInitial'],
      'sitio': map['sitio'],
      'phone_number': encrypt(map['phone_number'] ?? map['phoneNumber']),
      'pin_code': encrypt(map['pin_code'] ?? map['pin_code'] ?? map['pinCode']),
      'gender': map['gender'],
      'date_of_birth': map['date_of_birth'] ?? map['dateOfBirth'],
      'parent_id': map['parent_id'] ?? map['parentId'],
      'created_at': map['created_at'],
      'updated_at': DateTime.now().toIso8601String(),
      'is_deleted':
          (map['is_deleted'] == true || map['is_deleted'] == 1) ? 1 : 0,
      'is_active': (map['is_active'] == true ||
              map['is_active'] == 1 ||
              map['isActive'] == true ||
              map['isActive'] == 1)
          ? 1
          : 0,
      'is_synced': 0, // Mark for re-sync
      'pin_hash': map['pin_hash'],
      'pin_salt': map['pin_salt'],
    };
    await db.update('patients', encryptedMap,
        where: 'id = ?', whereArgs: [user.id]);
  }

  Future<void> deletePatient(String id) async {
    await db.update(
        'patients',
        {
          'is_deleted': 1,
          'is_synced': 0,
          'updated_at': DateTime.now().toIso8601String()
        },
        where: 'id = ?',
        whereArgs: [id]);
  }

  Future<List<User>> getUnsyncedPatients() async {
    final maps = await db.query(
      'patients',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
    return maps.map((map) {
      final decrypted = Map<String, dynamic>.from(map);
      decrypted['phoneNumber'] = decrypt(map['phone_number']?.toString() ?? '');
      decrypted['pinCode'] = decrypt(map['pin_code']?.toString() ?? '');
      decrypted['pin_hash'] = map['pin_hash'];
      decrypted['pin_salt'] = map['pin_salt'];
      return User.fromMap(decrypted);
    }).toList();
  }

  Future<void> markPatientAsSynced(String id) async {
    await db.update(
      'patients',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
