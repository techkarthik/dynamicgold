class Branch {
  final String branchId;
  final String branchName;
  final String companyId;
  final String? companyName;
  final String accountName;
  final String state;
  final int? stateId;
  final String country;
  final int? countryId;
  final String address;
  final String mobile;
  final String email;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;

  Branch({
    required this.branchId,
    required this.branchName,
    required this.companyId,
    this.companyName,
    this.accountName = '',
    this.state = '',
    this.stateId,
    this.country = 'India',
    this.countryId = 1,
    this.address = '',
    this.mobile = '',
    this.email = '',
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    final activeRaw = json['is_active'];
    final bool activeBool = (activeRaw == 1 || activeRaw == true || activeRaw == '1' || activeRaw == 'yes');

    return Branch(
      branchId: json['branchid']?.toString().trim().toUpperCase() ?? '',
      branchName: json['branchname']?.toString() ?? '',
      companyId: json['companyid']?.toString().trim().toUpperCase() ?? '',
      companyName: json['companyname']?.toString(),
      accountName: json['accountname']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      stateId: json['state_id'] != null ? int.tryParse(json['state_id'].toString()) : null,
      country: json['country']?.toString() ?? 'India',
      countryId: json['country_id'] != null ? int.tryParse(json['country_id'].toString()) : 1,
      address: json['address']?.toString() ?? '',
      mobile: json['mobile']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      isActive: activeBool,
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'branchid': branchId,
      'branchname': branchName,
      'companyid': companyId,
      'accountname': accountName,
      'state': state,
      if (stateId != null) 'state_id': stateId,
      'country': country,
      if (countryId != null) 'country_id': countryId,
      'address': address,
      'mobile': mobile,
      'email': email,
      'is_active': isActive ? 1 : 0,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  Branch copyWith({
    String? branchId,
    String? branchName,
    String? companyId,
    String? companyName,
    String? accountName,
    String? state,
    int? stateId,
    String? country,
    int? countryId,
    String? address,
    String? mobile,
    String? email,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
  }) {
    return Branch(
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      accountName: accountName ?? this.accountName,
      state: state ?? this.state,
      stateId: stateId ?? this.stateId,
      country: country ?? this.country,
      countryId: countryId ?? this.countryId,
      address: address ?? this.address,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
