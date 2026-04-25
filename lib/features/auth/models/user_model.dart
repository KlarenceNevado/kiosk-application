import 'dart:convert';

class User {
  final String id;
  final String firstName;
  final String middleInitial;
  final String lastName;
  final String sitio;
  final String phoneNumber;
  final String pinCode; // LEGACY: For migration only
  final String? pinHash; // NEW: One-way security
  final String? pinSalt; // NEW: Unique user salt
  final DateTime dateOfBirth;
  final String gender;
  final String? parentId;
  final bool isSynced;
  final DateTime? updatedAt;
  final bool isDeleted;
  final bool isActive;
  final String? relation;
  final String role;
  final String? deviceToken;
  final String username;
  final int? fingerprintId; // NEW: Biometric ID (1-1000)
  final String? assignedBhwId; // NEW: Assigned Health Worker
  final String? assignedBhwName; // NEW: Display name for BHW

  User({
    required this.id,
    required this.firstName,
    required this.middleInitial,
    required this.lastName,
    required this.sitio,
    required this.phoneNumber,
    required this.pinCode,
    this.pinHash,
    this.pinSalt,
    required this.dateOfBirth,
    required this.gender,
    this.parentId,
    this.isSynced = false,
    this.updatedAt,
    this.isDeleted = false,
    this.isActive = true,
    this.relation,
    this.role = 'patient',
    this.deviceToken,
    required this.username,
    this.fingerprintId,
    this.assignedBhwId,
    this.assignedBhwName,
  });

  String get fullName {
    if (middleInitial.isEmpty) return "$firstName $lastName";
    final mi = middleInitial.endsWith('.') ? middleInitial : '$middleInitial.';
    return "$firstName $mi $lastName";
  }

  // Helper to calculate age
  int get age {
    final now = DateTime.now();
    int age = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      age--;
    }
    return age;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firstName': firstName,
      'middleInitial': middleInitial,
      'lastName': lastName,
      'sitio': sitio,
      'phoneNumber': phoneNumber,
      'pinCode': pinCode,
      'pin_hash': pinHash,
      'pin_salt': pinSalt,
      'dateOfBirth': dateOfBirth.toIso8601String(),
      'gender': gender,
      'parentId': parentId,
      'is_synced': isSynced ? 1 : 0,
      'updated_at': updatedAt?.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
      'isActive': isActive ? 1 : 0,
      'relation': relation,
      'role': role,
      'device_token': deviceToken,
      'username': username,
      'fingerprint_id': fingerprintId,
      'assigned_bhw_id': assignedBhwId,
      'assigned_bhw_name': assignedBhwName,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    bool parseBool(dynamic value, bool defaultValue) {
      if (value == null) return defaultValue;
      if (value is bool) return value;
      if (value is int) return value == 1;
      if (value is String) return value.toLowerCase() == 'true' || value == '1';
      return defaultValue;
    }

    return User(
      id: map['id'] ?? '',
      firstName: map['firstName'] ?? map['first_name'] ?? '',
      middleInitial: map['middleInitial'] ?? map['middle_initial'] ?? '',
      lastName: map['lastName'] ?? map['last_name'] ?? '',
      sitio: map['sitio'] ?? '',
      phoneNumber: map['phoneNumber'] ?? map['phone_number'] ?? '',
      pinCode: map['pinCode'] ?? map['pin_code'] ?? '123456',
      pinHash: map['pin_hash'] ?? map['pinHash'],
      pinSalt: map['pin_salt'] ?? map['pinSalt'],
      dateOfBirth:
          DateTime.tryParse(map['dateOfBirth'] ?? map['date_of_birth'] ?? '') ??
              DateTime.now(),
      gender: map['gender'] ?? 'Not Specified',
      parentId: map['parentId'] ?? map['parent_id'],
      isSynced: parseBool(map['isSynced'] ?? map['is_synced'], false),
      updatedAt: DateTime.tryParse(map['updated_at'] ?? ''),
      isDeleted: parseBool(map['is_deleted'], false),
      isActive: parseBool(map['isActive'] ?? map['is_active'], true),
      relation: map['relation'],
      role: map['role'] ?? 'patient',
      deviceToken: map['deviceToken'] ?? map['device_token'],
      username: map['username'] ?? '',
      fingerprintId: map['fingerprint_id'] != null ? (map['fingerprint_id'] as num).toInt() : null,
      assignedBhwId: map['assigned_bhw_id'] ?? map['assignedBhwId'],
      assignedBhwName: map['assigned_bhw_name'] ?? map['assignedBhwName'],
    );
  }

  String toJson() => json.encode(toMap());

  User copyWith({
    String? id,
    String? firstName,
    String? middleInitial,
    String? lastName,
    String? sitio,
    String? phoneNumber,
    String? pinCode,
    String? pinHash,
    String? pinSalt,
    DateTime? dateOfBirth,
    String? gender,
    String? parentId,
    bool? isSynced,
    DateTime? updatedAt,
    bool? isDeleted,
    bool? isActive,
    String? relation,
    String? role,
    String? deviceToken,
    String? username,
    int? fingerprintId,
    String? assignedBhwId,
    String? assignedBhwName,
  }) {
    return User(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      middleInitial: middleInitial ?? this.middleInitial,
      lastName: lastName ?? this.lastName,
      sitio: sitio ?? this.sitio,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      pinCode: pinCode ?? this.pinCode,
      pinHash: pinHash ?? this.pinHash,
      pinSalt: pinSalt ?? this.pinSalt,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      parentId: parentId ?? this.parentId,
      isSynced: isSynced ?? this.isSynced,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      isActive: isActive ?? this.isActive,
      relation: relation ?? this.relation,
      role: role ?? this.role,
      deviceToken: deviceToken ?? this.deviceToken,
      username: username ?? this.username,
      fingerprintId: fingerprintId ?? this.fingerprintId,
      assignedBhwId: assignedBhwId ?? this.assignedBhwId,
      assignedBhwName: assignedBhwName ?? this.assignedBhwName,
    );
  }

  factory User.fromJson(String source) => User.fromMap(json.decode(source));

  factory User.empty() => User(
        id: '',
        firstName: '',
        middleInitial: '',
        lastName: '',
        sitio: '',
        phoneNumber: '',
        pinCode: '123456',
        dateOfBirth: DateTime.now(),
        gender: '',
        username: 'unknown',
      );
}
