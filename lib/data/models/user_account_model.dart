class UserAccountModel {
  final int? id;
  final String accountNumber;
  final String dialCode;
  final String phoneNational;
  final String fullName;
  final String region; // 'A': صنعاء, 'B': عدن
  final bool isVerified;
  final bool biometricEnabled;
  final DateTime createdAt;

  UserAccountModel({
    this.id,
    required this.accountNumber,
    required this.dialCode,
    required this.phoneNational,
    required this.fullName,
    required this.region,
    this.isVerified = false,
    this.biometricEnabled = false,
    required this.createdAt,
  });

  String get regionName => region == 'A' ? 'صنعاء' : (region == 'B' ? 'عدن' : region);

  factory UserAccountModel.fromJson(Map<String, dynamic> json) {
    return UserAccountModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      accountNumber: json['account_number'] ?? '',
      dialCode: json['dial_code'] ?? '+967',
      phoneNational: json['phone_national'] ?? '',
      fullName: json['full_name'] ?? '',
      region: json['region'] ?? 'A',
      isVerified: json['is_verified'] ?? false,
      biometricEnabled: json['biometric_enabled'] ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'account_number': accountNumber,
      'dial_code': dialCode,
      'phone_national': phoneNational,
      'full_name': fullName,
      'region': region,
      'is_verified': isVerified,
      'biometric_enabled': biometricEnabled,
    };
  }

  UserAccountModel copyWith({
    int? id,
    String? accountNumber,
    String? dialCode,
    String? phoneNational,
    String? fullName,
    String? region,
    bool? isVerified,
    bool? biometricEnabled,
    DateTime? createdAt,
  }) {
    return UserAccountModel(
      id: id ?? this.id,
      accountNumber: accountNumber ?? this.accountNumber,
      dialCode: dialCode ?? this.dialCode,
      phoneNational: phoneNational ?? this.phoneNational,
      fullName: fullName ?? this.fullName,
      region: region ?? this.region,
      isVerified: isVerified ?? this.isVerified,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
