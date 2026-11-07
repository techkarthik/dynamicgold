class BankAccountDetail {
  final String bankName;
  final String accountNumber;
  final String ifscCode;
  final String branchName;
  final String accountHolderName;
  final String upiId;

  BankAccountDetail({
    this.bankName = '',
    this.accountNumber = '',
    this.ifscCode = '',
    this.branchName = '',
    this.accountHolderName = '',
    this.upiId = '',
  });

  factory BankAccountDetail.fromJson(Map<String, dynamic> json) {
    return BankAccountDetail(
      bankName: json['bank_name']?.toString() ?? json['bankName']?.toString() ?? '',
      accountNumber: json['account_number']?.toString() ?? json['accountNumber']?.toString() ?? '',
      ifscCode: json['ifsc_code']?.toString() ?? json['ifscCode']?.toString() ?? '',
      branchName: json['branch_name']?.toString() ?? json['branchName']?.toString() ?? '',
      accountHolderName: json['account_holder_name']?.toString() ?? json['accountHolderName']?.toString() ?? '',
      upiId: json['upi_id']?.toString() ?? json['upiId']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bank_name': bankName,
      'account_number': accountNumber,
      'ifsc_code': ifscCode,
      'branch_name': branchName,
      'account_holder_name': accountHolderName,
      'upi_id': upiId,
    };
  }

  BankAccountDetail copyWith({
    String? bankName,
    String? accountNumber,
    String? ifscCode,
    String? branchName,
    String? accountHolderName,
    String? upiId,
  }) {
    return BankAccountDetail(
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      ifscCode: ifscCode ?? this.ifscCode,
      branchName: branchName ?? this.branchName,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      upiId: upiId ?? this.upiId,
    );
  }
}

class AccountHead {
  final int? id;
  final String accode;
  final String groupname;
  final String accountname;
  final String accounttype; // CASH, SMITH, DEALER, BANK, OTHER, INTERNAL, or custom
  final List<BankAccountDetail> bankAccounts;
  final String addressLine1;
  final String addressLine2;
  final String city;
  final String state;
  final String country;
  final String pincode;
  final String phoneNo;
  final String email;
  final int active; // 1 = active, 0 = inactive
  final String gstno;
  final String panno;
  final String? createdAt;
  final String? updatedAt;

  AccountHead({
    this.id,
    required this.accode,
    required this.groupname,
    required this.accountname,
    this.accounttype = 'OTHER',
    this.bankAccounts = const [],
    this.addressLine1 = '',
    this.addressLine2 = '',
    this.city = '',
    this.state = '',
    this.country = 'India',
    this.pincode = '',
    this.phoneNo = '',
    this.email = '',
    this.active = 1,
    this.gstno = '',
    this.panno = '',
    this.createdAt,
    this.updatedAt,
  });

  factory AccountHead.fromJson(Map<String, dynamic> json) {
    List<BankAccountDetail> parsedBanks = [];
    if (json['bank_details'] is List) {
      parsedBanks = (json['bank_details'] as List)
          .map((b) => b is Map<String, dynamic> ? BankAccountDetail.fromJson(b) : BankAccountDetail.fromJson(Map<String, dynamic>.from(b as Map)))
          .toList();
    } else if (json['bankAccounts'] is List) {
      parsedBanks = (json['bankAccounts'] as List)
          .map((b) => b is Map<String, dynamic> ? BankAccountDetail.fromJson(b) : BankAccountDetail.fromJson(Map<String, dynamic>.from(b as Map)))
          .toList();
    }

    return AccountHead(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      accode: json['accode']?.toString() ?? '',
      groupname: json['groupname']?.toString() ?? '',
      accountname: json['accountname']?.toString() ?? '',
      accounttype: json['accounttype']?.toString().trim().toUpperCase().isNotEmpty == true
          ? json['accounttype'].toString().trim().toUpperCase()
          : 'OTHER',
      bankAccounts: parsedBanks,
      addressLine1: json['address_line1']?.toString() ?? json['addressLine1']?.toString() ?? '',
      addressLine2: json['address_line2']?.toString() ?? json['addressLine2']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      country: json['country']?.toString() ?? 'India',
      pincode: json['pincode']?.toString() ?? '',
      phoneNo: json['phone_no']?.toString() ?? json['phoneNo']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      active: json['active'] != null ? int.tryParse(json['active'].toString()) ?? 1 : 1,
      gstno: json['gstno']?.toString() ?? '',
      panno: json['panno']?.toString() ?? '',
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'accode': accode,
      'groupname': groupname,
      'accountname': accountname,
      'accounttype': accounttype,
      'bank_details': bankAccounts.map((b) => b.toJson()).toList(),
      'address_line1': addressLine1,
      'address_line2': addressLine2,
      'city': city,
      'state': state,
      'country': country,
      'pincode': pincode,
      'phone_no': phoneNo,
      'email': email,
      'active': active,
      'gstno': gstno,
      'panno': panno,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  AccountHead copyWith({
    int? id,
    String? accode,
    String? groupname,
    String? accountname,
    String? accounttype,
    List<BankAccountDetail>? bankAccounts,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? country,
    String? pincode,
    String? phoneNo,
    String? email,
    int? active,
    String? gstno,
    String? panno,
    String? createdAt,
    String? updatedAt,
  }) {
    return AccountHead(
      id: id ?? this.id,
      accode: accode ?? this.accode,
      groupname: groupname ?? this.groupname,
      accountname: accountname ?? this.accountname,
      accounttype: accounttype ?? this.accounttype,
      bankAccounts: bankAccounts ?? this.bankAccounts,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      pincode: pincode ?? this.pincode,
      phoneNo: phoneNo ?? this.phoneNo,
      email: email ?? this.email,
      active: active ?? this.active,
      gstno: gstno ?? this.gstno,
      panno: panno ?? this.panno,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
