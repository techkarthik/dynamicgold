class Company {
  final String companyId;
  final String companyName;
  final String gstNo;
  final String mobileNumber;
  final String address;
  final String city;
  final String state;
  final int? stateId;
  final String country;
  final int? countryId;
  final String accountName;
  final String branchId;
  final String? createdAt;
  final String? updatedAt;

  Company({
    required this.companyId,
    required this.companyName,
    this.gstNo = '',
    this.mobileNumber = '',
    this.address = '',
    this.city = '',
    this.state = '',
    this.stateId,
    this.country = 'India',
    this.countryId = 1,
    this.accountName = '',
    this.branchId = '',
    this.createdAt,
    this.updatedAt,
  });

  /// Parse branch IDs into a clean List of Strings
  List<String> get branchList {
    if (branchId.isEmpty) return [];
    return branchId
        .split(',')
        .map((b) => b.trim())
        .where((b) => b.isNotEmpty)
        .toList();
  }

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      companyId: json['companyid']?.toString().trim().toUpperCase() ?? '',
      companyName: json['companyname']?.toString() ?? '',
      gstNo: json['gstno']?.toString() ?? '',
      mobileNumber: json['mobilenumber']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      stateId: json['state_id'] != null
          ? int.tryParse(json['state_id'].toString())
          : null,
      country: json['country']?.toString() ?? 'India',
      countryId: json['country_id'] != null
          ? int.tryParse(json['country_id'].toString())
          : 1,
      accountName: json['accountname']?.toString() ?? '',
      branchId: json['branchid']?.toString() ?? '',
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'companyid': companyId,
      'companyname': companyName,
      'gstno': gstNo,
      'mobilenumber': mobileNumber,
      'address': address,
      'city': city,
      'state': state,
      if (stateId != null) 'state_id': stateId,
      'country': country,
      if (countryId != null) 'country_id': countryId,
      'accountname': accountName,
      'branchid': branchId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  Company copyWith({
    String? companyId,
    String? companyName,
    String? gstNo,
    String? mobileNumber,
    String? address,
    String? city,
    String? state,
    int? stateId,
    String? country,
    int? countryId,
    String? accountName,
    String? branchId,
    String? createdAt,
    String? updatedAt,
  }) {
    return Company(
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      gstNo: gstNo ?? this.gstNo,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      stateId: stateId ?? this.stateId,
      country: country ?? this.country,
      countryId: countryId ?? this.countryId,
      accountName: accountName ?? this.accountName,
      branchId: branchId ?? this.branchId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
